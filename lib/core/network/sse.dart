import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_client.dart';

/// SSE 帧。
///
/// 实测（2026-08-29/30 抓包）以**真实后端**为准，不盲从《接口对接文档》3.2：
/// - 增量正文字段是 **`data`**（兼容旧文档的 `content`）。
/// - 存在两套流式通道，帧类型不统一，解析需兼容两者：
///   * `experience:stream`：`MODEL_STARTED` / `ANSWER_DELTA` / `MODEL_COMPLETED`
///   * `conversations/turns:stream`（Web 同源、可归档）：`*_STARTED`（首帧带
///     `chatSessionId`）/ `*_DELTA` / `done` / `finished`
/// - 归档通道的首帧会回填 `chatSessionId`（见 [SseFrame.sessionId]），
///   客户端据此把消息挂到会话下，web 端 `his/record/list` 才能看到。
class SseFrame {
  const SseFrame({
    required this.type,
    this.content,
    this.phase,
    this.status,
    this.waitingRank,
    this.activeCount,
    this.limit,
    this.raw = const {},
  });

  final String type;

  /// 增量正文（来自 `data` 字段；兼容旧文档的 `content`）
  final String? content;
  final String? phase;
  final String? status;

  /// 排队信息（TURN_DEQUEUED 携带）
  final int? waitingRank;
  final int? activeCount;
  final int? limit;

  final Map<String, dynamic> raw;

  factory SseFrame.fromJson(Map<String, dynamic> json) => SseFrame(
        // 实测字段为 data；保留 content 作为兼容回退
        type: (json['type'] ?? '').toString(),
        content: (json['data'] ?? json['content'])?.toString(),
        phase: json['phase']?.toString(),
        status: json['status']?.toString(),
        waitingRank: _asInt(json['waitingRank']),
        activeCount: _asInt(json['activeCount']),
        limit: _asInt(json['limit']),
        raw: json,
      );

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool get isDelta => type.contains('DELTA');

  /// 排队中（可展示「排队中，第 N 位」）。
  /// turns:stream 的排队帧有 `TURN_QUEUED` 与 `QUEUE_POSITION_UPDATED`
  /// 两种，均携带 waitingRank/activeCount/limit（兼容旧 experience:stream 的 TURN_DEQUEUED）。
  bool get isQueued =>
      type == 'TURN_DEQUEUED' ||
      type == 'TURN_QUEUED' ||
      type == 'QUEUE_POSITION_UPDATED';
  bool get isStarted => type == 'MODEL_STARTED' || type.contains('STARTED');
  bool get isThinking => isQueued || isStarted;

  /// 结束帧：兼容 experience:stream（MODEL_COMPLETED）与
  /// conversations/turns:stream（done / finished / *complete*）多种写法。
  bool get isDone =>
      type == 'MODEL_COMPLETED' ||
      type == 'TURN_COMPLETED' ||
      type == 'DONE' ||
      type == 'done' ||
      type == 'finished' ||
      type == '[DONE]' ||
      type.toLowerCase().contains('complete');

  bool get isError =>
      type == 'ERROR' ||
      type == 'error' ||
      type == 'MODEL_FAILED' ||
      type == 'TURN_FAILED' ||
      type.toLowerCase().contains('error') ||
      (raw['status']?.toString().toUpperCase() == 'FAILED');

  /// 会话 id：服务端首帧（STARTED）回填的 `chatSessionId` / `sessionId`，
  /// 用于把本轮消息归档到会话下（his/record/list 可拉到、web 端可见）。
  String? get sessionId =>
      (raw['chatSessionId'] ?? raw['sessionId'] ?? raw['session_id'])?.toString();
}

/// 流式订阅句柄：调用 [SseSubscription.cancel] 即中断生成（UI「停止生成」）。
class SseSubscription {
  SseSubscription(this._client);

  final http.Client _client;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _client.close();
  }

  /// 超时后由 SseClient 内部标记，避免继续向已失效的回调推送
  void _markTimeout() {
    _cancelled = true;
  }
}

/// SSE 客户端：以 POST 发起流式对话并逐帧回调。
///
/// 内置两道超时防线，确保**永不无声卡死**：
/// - [firstFrameTimeout]：连接后迟迟没有任何帧 → 报错
/// - [stallTimeout]：中途长时间没有新帧 → 报错
class SseClient {
  SseClient({
    required this.token,
    this.firstFrameTimeout = const Duration(seconds: 25),
    this.stallTimeout = const Duration(seconds: 40),
  });

  final String token;
  final Duration firstFrameTimeout;
  final Duration stallTimeout;

  SseSubscription postStream({
    required String path,
    required Map<String, dynamic> body,
    required void Function(SseFrame frame) onFrame,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) {
    final client = http.Client();
    final subscription = SseSubscription(client);
    unawaited(_run(client, subscription, path, body, onFrame, onError, onDone));
    return subscription;
  }

  Future<void> _run(
    http.Client client,
    SseSubscription subscription,
    String path,
    Map<String, dynamic> body,
    void Function(SseFrame frame) onFrame,
    void Function(Object error)? onError,
    void Function()? onDone,
  ) async {
    final pending = StringBuffer();
    bool gotFirstFrame = false;
    Timer? watchdog;

    void arm() {
      watchdog?.cancel();
      if (subscription.isCancelled) return;
      final wait = gotFirstFrame ? stallTimeout : firstFrameTimeout;
      watchdog = Timer(wait, () {
        if (subscription.isCancelled) return;
        subscription._markTimeout();
        client.close();
        onError?.call(
          gotFirstFrame
              ? TimeoutException('模型 ${stallTimeout.inSeconds}s 未再返回数据，已中断')
              : TimeoutException('模型 ${firstFrameTimeout.inSeconds}s 内无任何响应'),
        );
      });
    }

    try {
      final request = http.Request('POST', Uri.parse('${AppConfig.apiBase}$path'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          // 注意：不要加 `Cache-Control`。它是 CORS 非安全头，浏览器会因此
          // 强制发 preflight，而后端 access-control-allow-headers 列表里没有
          // `cache-control` → 预检被拒 → 整个 SSE 被 CORS 拦死（web 端聊天
          // 直接失败，桌面端 native HTTP 不受影响）。实测后端对 GET/POST/OPTIONS
          // 都正确返回 access-control-allow-origin:*，唯独不允许 cache-control。
          'X-Client-Type': AppConfig.clientType,
          'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode(body);

      final response =
          await client.send(request).timeout(AppConfig.streamTimeout);
      if (response.statusCode != 200) {
        throw ApiException(response.statusCode, '流式请求失败（${response.statusCode}）');
      }
      arm(); // 连接已建立 → 启动「首帧」计时

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (subscription.isCancelled) return;

        pending.write(chunk);
        final text = pending.toString();
        final cut = text.lastIndexOf('\n');
        if (cut < 0) continue; // 半包，等下一块

        final complete = text.substring(0, cut);
        final rest = text.substring(cut + 1);
        pending.clear();
        pending.write(rest);

        for (final line in const LineSplitter().convert(complete)) {
          if (subscription.isCancelled) return;

          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;

          var payload = trimmed;
          if (payload.startsWith('data:')) {
            payload = payload.substring(5).trim();
          }
          if (payload.isEmpty) continue;
          if (payload == '[DONE]') {
            onDone?.call();
            return;
          }

          Object? decoded;
          try {
            decoded = jsonDecode(payload);
          } catch (_) {
            continue; // 心跳 / 非 JSON 行
          }
          if (decoded is! Map<String, dynamic>) continue;

          final frame = SseFrame.fromJson(decoded);
          gotFirstFrame = true; // 收到任意帧 → 首帧计时结束
          onFrame(frame);
          arm(); // 每收到一帧重置「卡死」计时，并切到 stall 计时
          if (frame.isDone) {
            onDone?.call();
            return;
          }
        }
      }
      onDone?.call();
    } catch (error) {
      if (subscription.isCancelled) return;
      client.close();
      onError?.call(error);
    }
  }
}
