import 'dart:math';

import '../../core/network/api_client.dart';
import '../../core/network/sse.dart';
import '../models/models.dart';

/// 历史会话分页结果（**游标分页**，禁止用页码硬翻）。
class SessionPage {
  const SessionPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<SessionSummary> items;
  final bool hasMore;
  final String? nextCursor;
}

/// 对话仓库：流式对话 + 历史会话。
class ChatRepository {
  ChatRepository({required ApiClient api, required String token})
      : _api = api,
        _token = token;

  final ApiClient _api;
  final String _token;

  /// POST /ai/chat/model/experience:stream
  ///
  /// 返回 [SseSubscription]，调用其 `cancel()` 即可「停止生成」。
  ///
  /// ⚠️ 这是**兜底**通道：主通道是 [streamTurn]（`/ai/chat/conversations/turns:stream`，
  /// 与 Web 端同源、首帧 STARTED 回填 chatSessionId、可归档）。当主通道契约不匹配
  /// （首帧前报错）时，[ChatController] 会自动回退到本方法，保证「能聊天」，
  /// 但本轮不会同步到 web（因为 experience:stream 不返回 sessionId、不归档）。
  SseSubscription streamChat({
    required String modelId,
    required List<Map<String, String>> messages,
    bool thinkEnable = false,
    /// 智能搜索场景传 'knowledge_search'（检索增强），普通对话传 null。
    String? searchType,
    /// 要继续的会话 id（首轮可空，由服务端首帧回填）。
    String? sessionId,
    required void Function(SseFrame frame) onFrame,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) {
    final body = <String, dynamic>{
      'requestId': _newRequestId(),
      'modelId': modelId,
      'messages': messages,
      'thinkEnable': thinkEnable,
    };
    if (searchType != null && searchType.isNotEmpty) {
      body['searchType'] = searchType;
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      body['sessionId'] = sessionId;
    }
    final sse = SseClient(token: _token);
    return sse.postStream(
      path: '/ai/chat/model/experience:stream',
      body: body,
      onFrame: onFrame,
      onError: onError,
      onDone: onDone,
    );
  }

  /// POST /ai/chat/his/record/list。
  ///
  /// 请求体必须与 Web 端保持一致（Postman 实测正常）：`{"filter":"","limit":30}`。
  /// **不要传 `cursor`**——带上 cursor 后端会据此返回翻页窗口而非完整首页，
  /// 导致 app 端列表顺序与 Postman / web 不一致（表现为「错乱」）。
  /// 后端按自身默认排序返回，顺序即权威顺序，客户端原样展示即可。
  ///
  /// [limit] 默认 100（前后端经验的折中值）：Web 端单页 30 对 app 端抽屉不够（实测
  /// 长列表用户下滑接近底部时已无法触发更多）；100 既能覆盖大多数会话场景，又
  /// 不至于一次拉回几千条把抽屉渲染卡爆。极端长会话走后端"按时间分组"展示，
  /// 不在前端无限下拉的范围内。
  Future<SessionPage> fetchSessions({int limit = 100, String? cursor}) async {
    final body = <String, dynamic>{
      'filter': '',
      'limit': limit,
    };
    // cursor 不再使用（见上方注释）；保留参数签名以便未来若后端修正
    // 翻页契约，可直接复用本方法。
    if (cursor != null && cursor.isNotEmpty) {
      body['cursor'] = cursor;
    }
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/chat/his/record/list',
      body: body,
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );

    final rawItems = data?['items'];
    final items = rawItems is List<dynamic>
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(SessionSummary.fromJson)
            .toList()
        : <SessionSummary>[];

    return SessionPage(
      items: items,
      hasMore: data?['hasMore'] == true,
      nextCursor: data?['nextCursor']?.toString(),
    );
  }

  /// POST /ai/chat/record/list —— 拉取某个历史会话的「消息明细」。
  ///
  /// 请求体对齐 Web 端：`{"chatSessionId":"...","limit":20}`（cursor 可选，首屏不传）。
  ///
  /// 实测响应结构（2026-08-30）：
  /// ```json
  /// {
  ///   "code": 200, "msg": null, "type": "success",
  ///   "data": {
  ///     "chatSession": { "id": ..., "titleName": "...", ... },
  ///     "messageList": [
  ///       { "id": ..., "role": "user",      "content": "...", "msgTime": 1788066852282, "createTime": "2026-08-30 13:14:12", "turnSeq": 1, ... },
  ///       { "id": ..., "role": "assistant", "content": "...", "msgTime": 1788066853243, "createTime": "2026-08-30 13:14:13", "turnSeq": 1, ... }
  ///     ],
  ///     "nextCursor": null, "hasMore": false
  ///   },
  ///   "ok": true, "fail": false
  /// }
  /// ```
  /// [ApiClient.post] 已经把外层 `code/data` 拆掉，所以进来 [data] 就已经是
  /// `decoded['data']`（即上面那个内层）。消息列表字段名固定为 **`messageList`**
  /// （不是 `items`/不是 `records`），按 `turnSeq` 升序还原上下顺序。
  Future<List<ChatMessage>> fetchSessionMessages({
    required String chatSessionId,
    int limit = 20,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/chat/record/list',
      body: <String, dynamic>{
        'chatSessionId': chatSessionId,
        'limit': limit,
      },
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );

    // 列表字段：优先看 `messageList`（实测字段名），再兼容历史 `items`/`records`/`list`。
    // 注意 ApiClient.post 已经拆过外层 `data`，这里不要再 fallback 到 `data['data']`。
    final rawItems = data?['messageList'] ??
        data?['items'] ??
        data?['records'] ??
        data?['list'];
    if (rawItems is! List) return const [];

    final list = rawItems.whereType<Map<String, dynamic>>().toList()
      ..sort((a, b) {
        // 同一 turnSeq（如同一问答对 user+assistant）按 msgTime 兜底；
        // turnSeq 缺失时退化为 0，按位置先后排。
        final sa = (a['turnSeq'] as num?)?.toInt() ?? 0;
        final sb = (b['turnSeq'] as num?)?.toInt() ?? 0;
        if (sa != sb) return sa.compareTo(sb);
        final ta = (a['msgTime'] as num?)?.toInt() ?? 0;
        final tb = (b['msgTime'] as num?)?.toInt() ?? 0;
        return ta.compareTo(tb);
      });

    return list.map(_parseRecordMessage).toList(growable: false);
  }

  /// 把单条「带 role 的消息」解析为 [ChatMessage]。
  /// 实测每条都是平铺的 `{ id, role: "user"|"assistant", content, msgTime, createTime, ... }`。
  ChatMessage _parseRecordMessage(Map<String, dynamic> raw) {
    final roleRaw = (raw['role'] ?? raw['sender'])?.toString().toLowerCase();
    final isUser = roleRaw == 'user' || roleRaw == 'human' || roleRaw == '1';
    final content =
        _firstNonEmpty([raw['content'], raw['message'], raw['text']]) ?? '';

    // 思考内容：当前响应里没有显式字段（agentEvents 是过程事件流，不是思考文本）；
    // 字段名兜底几个常见命名，后续真出现某天服务端下发"思考"再接上。
    final thinking = _blankToNull(_firstNonEmpty([
      raw['thinking'],
      raw['reasoning'],
      raw['thinkContent'],
      raw['aiThinkContent'],
    ]));

    return ChatMessage(
      id: (raw['id'] ?? raw['messageId'] ?? _genId()).toString(),
      role: isUser ? ChatRole.user : ChatRole.assistant,
      content: content,
      thinking: thinking,
      createdAt: _parseRecordTime(raw),
    );
  }

  /// 优先用 Long 时间戳 `msgTime`（ms），缺则退到 `createTime` 字符串（"yyyy-MM-dd HH:mm:ss"）。
  DateTime _parseRecordTime(Map<String, dynamic> raw) {
    final mt = raw['msgTime'];
    if (mt is num) {
      return DateTime.fromMillisecondsSinceEpoch(mt.toInt());
    }
    if (mt is String) {
      final ms = int.tryParse(mt);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    final create = raw['createTime']?.toString();
    if (create != null && create.isNotEmpty) {
      final iso = create.contains('T') ? create : create.replaceFirst(' ', 'T');
      final dt = DateTime.tryParse(iso);
      if (dt != null) return dt;
    }
    return DateTime.now();
  }



  String? _firstNonEmpty(List<Object?> values) {
    for (final v in values) {
      final s = v?.toString();
      if (s != null && s.trim().isNotEmpty) return s;
    }
    return null;
  }

  String? _blankToNull(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;

  String _genId() {
    final random = Random.secure();
    return List<int>.generate(8, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// POST /ai/chat/conversations/turns:stream
  ///
  /// 与 **Web 端逐字对齐**的归档式流式对话（body 结构已逆向 web 前端
  /// ChatView → `Me(Ue)` → conversation-turn-stream client 确认）：
  /// - `sessionMode`：普通对话固定 `"CHAT"`（知识库检索才是 `"KNOWLEDGE"`）。
  /// - `message`：**单条** `{text, resources:[]}`（只发最后一条用户消息，
  ///   历史上下文由后端按 `sessionId` 续接，**不要传 messages 数组**）。
  /// - `execution.modelId`：模型 id 嵌套在 `execution` 下（不是顶层 `modelId`）。
  /// - `sessionId`：新对话传空串，后端首帧 `TURN_STARTED` 回填 `chatSessionId`
  ///   （见 [SseFrame.sessionId]），归档后 web 端 `his/record/list` 可见。
  /// - `client.capabilityCatalogVersion`：普通对话可空串（web 在无能力目录时
  ///   也发 `""`）；`thinkEnable` 为真时作为顶层字段带上。
  ///
  /// 之前按臆测发的 `messages` 数组 + 顶层 `modelId` + `chatSourceType:'NORMAL'`
  /// 会被后端判定缺参直接 500；现已对齐 web 真实契约。
  SseSubscription streamTurn({
    required String modelId,
    /// 单条最新用户消息文本（turns:stream 只发最后一条，上下文由服务端按
    /// sessionId 续接，不传历史 messages 数组）。
    required String text,
    bool thinkEnable = false,
    /// 智能体（Skill）id：从智能体详情 → 「开始对话」进入时绑定；
    /// null 表示普通对话。会话生命周期内保持绑定，新建对话时清理。
    String? agentId,
    /// 会话 id：新对话传空串，由后端首帧 TURN_STARTED 回填 chatSessionId。
    String sessionId = '',
    required void Function(SseFrame frame) onFrame,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) {
    final body = <String, dynamic>{
      'requestId': _newRequestId(),
      'sessionId': sessionId,
      'sessionMode': 'CHAT',
      'projectId': null,
      'message': {
        'text': text,
        'resources': <dynamic>[],
      },
      'execution': {
        'modelId': modelId,
        'agentId': agentId,
        'capabilityCodes': <String>[],
        'capabilityOptions': <String, dynamic>{},
        'confirmedCapabilityIds': <String>[],
      },
      'client': {
        'surface': 'PC',
        'capabilityCatalogVersion': '',
      },
    };
    if (thinkEnable) body['thinkEnable'] = true;
    final sse = SseClient(token: _token);
    return sse.postStream(
      path: '/ai/chat/conversations/turns:stream',
      body: body,
      onFrame: onFrame,
      onError: onError,
      onDone: onDone,
    );
  }

  /// 每次新建会话请求都需要全新的 requestId（UUID）。
  static String _newRequestId() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
