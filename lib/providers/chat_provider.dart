import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/sse.dart';
import '../data/models/models.dart';
import '../data/repositories/chat_repository.dart';
import 'auth_provider.dart';
import 'core_providers.dart';
import 'model_availability_provider.dart';
import 'model_provider.dart';

/// 对话仓库依赖登录 token，未登录时为 null。
final chatRepositoryProvider = Provider<ChatRepository?>((ref) {
  final token = ref.watch(authControllerProvider.select((s) => s.accessToken));
  if (token == null || token.isEmpty) return null;
  return ChatRepository(api: ref.watch(apiClientProvider), token: token);
});

/// 对话状态：消息列表 + 流式标记 + 历史会话（游标分页）。
class ChatState {
  const ChatState({
    this.messages = const [],
    this.sessions = const [],
    this.sessionId,
    this.modelId,
    /// 智能体（Skill）锁：从智能体详情 → 「开始对话」进入时绑定，
    /// 会话生命周期内保持；新建对话 / 切换智能体时显式清理。
    this.agentId,
    this.agentName,
    this.streaming = false,
    this.thinking = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
    this.sessionsLoading = false,
    this.historyLoading = false,
  });

  final List<ChatMessage> messages;
  final List<SessionSummary> sessions;
  final String? sessionId;
  final String? modelId;
  final String? agentId;
  final String? agentName;
  final bool streaming;
  final bool thinking;
  final bool hasMore;
  /// 历史会话下一页的游标；null 表示没有下一条或者后端未返回。
  /// 抽屉下滑接近底部时若 [hasMore] && [nextCursor] != null，
  /// chat_provider 会拉下一页并 append 到 sessions。
  final String? nextCursor;
  final String? error;
  final bool sessionsLoading;
  /// 正在拉取某个历史会话的消息明细（点击抽屉历史项时短暂为 true）。
  final bool historyLoading;

  bool get isEmpty => messages.isEmpty;

  ChatState copyWith({
    List<ChatMessage>? messages,
    List<SessionSummary>? sessions,
    String? sessionId,
    String? modelId,
    String? agentId,
    String? agentName,
    bool? streaming,
    bool? thinking,
    bool? hasMore,
    String? nextCursor,
    bool clearNextCursor = false,
    String? error,
    bool? sessionsLoading,
    bool? historyLoading,
    bool clearError = false,
    bool clearSessionId = false,
    bool clearAgent = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        sessions: sessions ?? this.sessions,
        // clearSessionId：传 null 想清空时，必须显式置位，
        // 否则 `?? this.sessionId` 会把 null 兜回旧值（Riverpod 经典坑）。
        sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
        modelId: modelId ?? this.modelId,
        agentId: clearAgent ? null : (agentId ?? this.agentId),
        agentName: clearAgent ? null : (agentName ?? this.agentName),
        streaming: streaming ?? this.streaming,
        thinking: thinking ?? this.thinking,
        hasMore: hasMore ?? this.hasMore,
        // clearNextCursor：清空 cursor 用（最后一页返回 hasMore=false 时配合使用）。
        nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
        error: clearError ? null : (error ?? this.error),
        sessionsLoading: sessionsLoading ?? this.sessionsLoading,
        historyLoading: historyLoading ?? this.historyLoading,
      );
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState());

  final Ref _ref;
  SseSubscription? _subscription;

  /// 本轮流式是否已收到正文（用于判定「空响应」= 模型不可用）。
  bool _contentReceived = false;

  ChatRepository? get _repository => _ref.read(chatRepositoryProvider);

  void setModel(String? modelId) => state = state.copyWith(modelId: modelId);

  /// 绑定当前对话到一个智能体（从智能体详情 → 「开始对话」调用）。
  /// - [name] 允许传 null（fallback 到空串）；UI 顶部显示绑定的 agent 名。
  void setAgent(String id, String? name) {
    state = state.copyWith(
      agentId: id,
      agentName: (name == null || name.isEmpty) ? null : name,
      clearSessionId: true, // 切智能体一定新开会话
      messages: const [],
      clearError: true,
    );
  }

  /// 解除智能体绑定（不影响当前会话，仅清未来的 streamTurn 注入）。
  void clearAgent() => state = state.copyWith(clearAgent: true);

  void newChat() {
    stop();
    state = state.copyWith(
      messages: const [],
      clearSessionId: true, // 显式置位才能真的清掉当前 sessionId（见 copyWith 注释）
      clearAgent: true, // 新对话默认不绑定智能体
      clearError: true,
    );
  }

  /// 发送消息并开启流式生成。
  /// [thinkEnable] 透传「深度思考」开关（对应 experience:stream 的 thinkEnable 参数）。
  void send(String text, {bool thinkEnable = false, List<Map<String, dynamic>> resources = const []}) {
    final content = text.trim();
    if (content.isEmpty || state.streaming) return;

    final userMessage =
        ChatMessage(id: _newId(), role: ChatRole.user, content: content);
    state = state.copyWith(messages: [...state.messages, userMessage]);
    _startStream(thinkEnable: thinkEnable, resources: resources);
  }

  /// 重新生成：丢弃上一条助手回复后重发最后一轮。
  void regenerate() {
    if (state.streaming) return;

    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isEmpty) return;
    if (!messages.last.isUser) messages.removeLast();
    if (messages.isEmpty || !messages.last.isUser) return;

    state = state.copyWith(messages: messages);
    _startStream();
  }

  /// 停止生成（取消 SSE 订阅）。
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _finish();
  }

  Future<void> _startStream({bool thinkEnable = false, List<Map<String, dynamic>> resources = const []}) async {
    final repository = _repository;
    final modelId = state.modelId;

    if (repository == null) {
      state = state.copyWith(error: '登录状态已失效，请重新登录', streaming: false);
      return;
    }
    if (modelId == null || modelId.isEmpty) {
      state = state.copyWith(error: '尚未选择模型，请先在模型面板中选择', streaming: false);
      return;
    }

    // 进入「检测中」：实时反映该模型当前可用性
    _ref.read(modelAvailabilityProvider.notifier).markChecking(modelId);
    _contentReceived = false;

    // 组装上下文：用户消息 + 已完成的助手消息（流式中的那条不参与）
    final history = state.messages
        .where((m) => m.isUser || m.status == MessageStatus.done)
        .map((m) => m.toRequestJson())
        .toList();

    final reply = ChatMessage(
      id: _newId(),
      role: ChatRole.assistant,
      status: MessageStatus.streaming,
    );

    state = state.copyWith(
      messages: [...state.messages, reply],
      streaming: true,
      thinking: true,
      clearError: true,
    );

    // 主通道 turns:stream 只认「单条最新用户消息」，上下文由服务端按 sessionId
    // 续接；从 history 里取最后一条用户消息的文本。
    final userText = history
        .where((m) => (m['role'] ?? '') == 'user')
        .map((m) => m['content'] ?? '')
        .where((c) => c.isNotEmpty)
        .lastOrNull ?? '';

    // 主通道：/ai/chat/conversations/turns:stream（与 Web 同源、契约逐字对齐，
    // 首帧 TURN_STARTED 回填 chatSessionId，消息归档后 web 端可见）。若其契约
    // 不匹配、首帧前就报错，_beginStream 会自动回退到 experience:stream，保证「能聊天」。
    _beginStream(modelId, history, userText, thinkEnable, useTurn: true, resources: resources);
  }

  /// 真正发起流式请求；[useTurn]=true 走归档主通道，false 走兜底 experience:stream。
  /// 主通道在「收到正文前」报错 → 回退兜底通道（仅回退一次，避免死循环）。
  /// [text] 为最新一条用户消息（给主通道 turns:stream 用）；[history] 为完整上下文
  /// （给兜底通道 experience:stream 用，它才需要 messages 数组）。
  void _beginStream(
    String modelId,
    List<Map<String, String>> history,
    String text,
    bool thinkEnable, {
    required bool useTurn,
    List<Map<String, dynamic>> resources = const [],
  }) {
    final repository = _repository;
    if (repository == null) return;

    void onError(Object error) {
      if (useTurn && !_contentReceived) {
        // 主通道契约不匹配（多半是 body 字段名差异），回退经验通道
        _beginStream(modelId, history, text, thinkEnable, useTurn: false, resources: resources);
        return;
      }
      _onError(error);
    }

    _subscription = useTurn
        ? repository.streamTurn(
            modelId: modelId,
            text: text,
            resources: resources,
            thinkEnable: thinkEnable,
            agentId: state.agentId,
            sessionId: state.sessionId ?? '',
            onFrame: _onFrame,
            onError: onError,
            onDone: _onDone,
          )
        : repository.streamChat(
            modelId: modelId,
            messages: history,
            thinkEnable: thinkEnable,
            sessionId: state.sessionId,
            onFrame: _onFrame,
            onError: onError,
            onDone: _onDone,
          );
  }

  void _onFrame(SseFrame frame) {
    if (frame.isThinking) {
      state = state.copyWith(thinking: true);
    }
    // 服务端首帧回填会话 id（兜底多种字段命名）：`chatSessionId` 优先（与
    // his/record/list 返回字段一致），其次 `sessionId`，最后 `data.sessionId`
    // （SSE 流里有时把 session 塞在 data 字段里）。仅当本地尚未持有
    // sessionId 时回填，避免覆盖 `openSession` 主动切到的历史会话。
    if (state.sessionId == null || state.sessionId!.isEmpty) {
      final found = frame.sessionId;
      if (found != null && found.isNotEmpty) {
        state = state.copyWith(sessionId: found);
      }
    }
    if (frame.isThinking) return;
    if (frame.isError) {
      final id = state.modelId;
      final reason = frame.raw['msg']?.toString() ?? '生成失败，请重试';
      if (id != null) {
        _ref.read(modelAvailabilityProvider.notifier).markUnavailable(
              id,
              reason: reason,
              modelName: _modelName(id),
            );
      }
      _fail(reason);
      return;
    }
    if (!frame.isDelta) return;

    final delta = frame.content;
    if (delta == null || delta.isEmpty) return;

    // 首个增量正文 → 标记该模型可用
    if (!_contentReceived) {
      _contentReceived = true;
      final id = state.modelId;
      if (id != null) {
        _ref.read(modelAvailabilityProvider.notifier).markAvailable(id);
      }
    }

    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isEmpty) return;

    // 增量追加到最后一个气泡 → 打字机效果
    messages.last.content = messages.last.content + delta;
    state = state.copyWith(messages: messages, thinking: false);
  }

  void _onDone() {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty) {
      messages.last.status = MessageStatus.done;
      // 流式结束但没有任何正文 → 该模型不可用（实测部分模型仅下发控制帧/空响应）
      if (!_contentReceived && !messages.last.isUser) {
        final id = state.modelId;
        if (id != null) {
          _ref.read(modelAvailabilityProvider.notifier).markUnavailable(
                id,
                reason: '模型未返回任何内容，可能暂不可用',
                modelName: _modelName(id),
              );
        }
      }
    }
    _subscription = null;
    state = state.copyWith(messages: messages, streaming: false, thinking: false);
    // 本轮正常结束 → 静默刷新历史列表，让新建/续写的会话尽快出现在抽屉
    // （不阻塞 UI；失败不影响主对话）
    unawaited(_refreshSessionsSilently());
  }

  /// 静默刷新历史会话列表（让新建的归档会话立即在抽屉可见）。
  Future<void> _refreshSessionsSilently() async {
    try {
      await loadSessions(refresh: true);
    } catch (_) {
      // 忽略：历史刷新失败不应影响对话
    }
  }

  void _onError(Object error) {
    final id = state.modelId;
    final isAuth = error is ApiException && error.code == 401;
    // 网络/CORS/超时/连接被拒 等环境层错误 → 不去污染模型可用性。
    // 这些是 Web 平台的 CORS 限制（或 DNS/网络层）问题，不是模型本身的问题，
    // 把它们标成「暂不可用」会冤枉本来能用的模型（已在桌面端验证可用的模型
    // 在 Web 端因 SSE CORS 失败被错误标红）。错误详情仍通过 _fail 显示给用户。
    final isNetwork = _isNetworkError(error);
    // 已经收到内容 → 仅清状态，不去污染 modelAvailability（避免"明明答案出来了还被标不可用"）
    if (id != null && !isAuth && !isNetwork && !_contentReceived) {
      _ref.read(modelAvailabilityProvider.notifier).markUnavailable(
            id,
            reason: _describeError(error),
            modelName: _modelName(id),
          );
    }
    _fail(_describeError(error));
  }

  /// 判断是否为「网络/CORS 环境层」错误（不是模型本身的问题）。
  /// 复用 [ApiException]/[TimeoutException] 的翻译规则，避免两套判定走偏。
  bool _isNetworkError(Object error) {
    if (error is TimeoutException) return true;
    final raw = error.toString();
    return raw.contains('Failed to fetch') ||
        raw.contains('XMLHttpRequest') ||
        raw.contains('SocketException') ||
        raw.contains('Connection refused') ||
        raw.contains('No address associated with hostname');
  }

  /// 把底层异常翻译为「给用户看的不可用原因 / 错误栏文案」。
  String _describeError(Object error) {
    if (error is ApiException) {
      if (error.code == 400) return 'HTTP 400：该模型暂未开通服务';
      if (error.code == 401) return '登录已失效，请重新登录';
      if (error.code == 403) return 'HTTP 403：当前账号无该模型使用权限';
      if (error.code == 404) return 'HTTP 404：模型接口不存在或已下线';
      if (error.code == 429) return '请求过于频繁，请稍后再试';
      if (error.code >= 500) return '后端服务异常（HTTP ${error.code}），请稍后再试';
      return error.message;
    }
    if (error is TimeoutException) return '响应超时，模型可能暂不可用';
    // Flutter Web 把跨域 / DNS / 后端域名不可达统一抛为 ClientException
    // 'Failed to fetch, uri=...'。原文贴出去用户根本看不懂，做友好化翻译。
    final raw = error.toString();
    if (raw.contains('Failed to fetch') ||
        raw.contains('XMLHttpRequest') ||
        raw.contains('SocketException') ||
        raw.contains('Connection refused') ||
        raw.contains('No address associated with hostname')) {
      return '请求未送达后端（多为 CORS 跨域被拦或测试域名不可达），请检查 DevTools Network 面板或联系后端放行本地访问';
    }
    return raw.isEmpty ? '网络异常，生成已中断' : raw;
  }

  /// 模型 id → 展示名（用于拼提示文案）。
  String _modelName(String id) {
    for (final m in _ref.read(modelControllerProvider).models) {
      if (m.id == id) return m.name;
    }
    return id;
  }

  void _fail(String message) {
    final messages = List<ChatMessage>.from(state.messages);
    final received = _contentReceived;
    // 已经收到内容：视为流正常结束（不要把消息标 failed，也别再提示错误）
    if (messages.isNotEmpty && !received) {
      messages.last.status = MessageStatus.failed;
    } else if (messages.isNotEmpty) {
      messages.last.status = MessageStatus.done;
    }
    _subscription = null;
    state = state.copyWith(
      messages: messages,
      streaming: false,
      thinking: false,
      // 已经收到内容 → 不再显示错误条，避免「答案已显示却又告诉用户出错」的矛盾
      error: received ? null : message,
    );
  }

  void _finish() {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && messages.last.status == MessageStatus.streaming) {
      messages.last.status = MessageStatus.done;
    }
    state = state.copyWith(messages: messages, streaming: false, thinking: false);
  }

  /// 拉取历史会话列表（POST /ai/chat/his/record/list）。
  ///
  /// 调用语义：
  /// - `refresh: true`  → **重新从首页拉**：清空 sessions 与 cursor，从头再来（用于下拉刷新）。
  /// - `refresh: false` → **拉下一页**：用现有 `nextCursor` 拉下一页，append 到 sessions。
  ///   如果服务端返回的 hasMore=false 且 nextCursor=null，本调用相当于 no-op。
  ///
  /// 第一页拉取策略：固定 `limit=100` 不带 cursor，匹配 Web/Postman 的请求体。
  /// 后续页：从响应里取 `nextCursor`/`hasMore`，在抽屉下滑触发后调用本方法拉下一页。
  Future<void> loadSessions({bool refresh = false}) async {
    final repository = _repository;
    if (repository == null) return;

    if (refresh) {
      // 用户主动下拉刷新：从头重拉第一页，清空旧列表与 cursor。
      state = state.copyWith(
        sessions: const [],
        hasMore: true,
        clearNextCursor: true,
      );
    } else {
      // 增量翻页：hasMore=false 时不再发请求（避免无限空转）。
      if (!state.hasMore) return;
    }

    state = state.copyWith(sessionsLoading: true);
    try {
      final cursor = refresh ? null : state.nextCursor;
      final page = await repository.fetchSessions(cursor: cursor);
      // 仅去重、保留后端返回顺序（不再客户端重排，避免打乱 web/Postman 顺序）。
      final combined = _sortSessions([...state.sessions, ...page.items]);
      state = state.copyWith(
        sessions: combined,
        // 用后端返回值作为权威；hasMore=false 时同步清空 nextCursor。
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        clearNextCursor: !page.hasMore || page.nextCursor == null,
        sessionsLoading: false,
      );
    } catch (_) {
      // 历史列表失败不影响主对话
      state = state.copyWith(sessionsLoading: false);
    }
  }

  /// 多端实时同步用的「静默轮询」。
  ///
  /// 与 [loadSessions(refresh:true)] 不同：本方法**不清空**现有列表、也**不显示
  /// loading 圈**，拉取后对比会话 id 列表；若与当前完全一致则不打扰 UI（避免
  /// 轮询时列表闪烁），仅当出现新增/删除会话时才更新 state——从而让另一端
  /// 新建的会话在本端自动出现（覆盖「A 设备建会话、B 设备不操作也看到」的场景）。
  Future<void> pollSessions() async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final page = await repository.fetchSessions(cursor: null);
      // 首页会话（后端权威顺序）。
      final home = _sortSessions(page.items);
      // 保留用户主动下滑翻页加载的「首页之外」条目，避免轮询把后端翻页结果清空
      // （抽屉历史 > 100 条时下滑会追加第 101+ 条，直接替换首页会丢失这些）。
      final extra = state.sessions.length > home.length
          ? state.sessions.sublist(home.length)
          : const <SessionSummary>[];
      final incoming = _sortSessions([...home, ...extra]);
      if (_sameSessions(incoming, state.sessions)) return; // 无变化，跳过
      state = state.copyWith(
        sessions: incoming,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        clearNextCursor: !page.hasMore || page.nextCursor == null,
      );
    } catch (_) {
      // 轮询失败静默忽略，下个周期再试
    }
  }

  /// 对比两个会话列表是否「完全一致」（同顺序、同 sessionId）。
  bool _sameSessions(List<SessionSummary> a, List<SessionSummary> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].sessionId != b[i].sessionId) return false;
    }
    return true;
  }

  /// 切换到某个历史会话并拉取消息明细。
  ///
  /// 点击左侧抽屉历史项时调用：先切 sessionId、清空消息、标记 historyLoading，
  /// 再调 `record/list` 拉该会话的问答明细回填 `messages`，对话屏随即展示历史。
  /// 后续继续提问会复用同一 sessionId，后端把新消息归档进去（web 端可见）。
  Future<void> openSession(String sessionId) async {
    stop();
    state = state.copyWith(
      sessionId: sessionId,
      messages: const [],
      historyLoading: true,
      clearError: true,
    );
    await _loadHistory(sessionId);
  }

  /// 拉取指定会话的消息明细，回填到 state.messages。
  /// 用 sessionId 守卫：若用户在请求途中切换了别的会话，则丢弃本次结果。
  Future<void> _loadHistory(String sessionId) async {
    final repository = _repository;
    if (repository == null) {
      if (state.sessionId == sessionId) {
        state = state.copyWith(historyLoading: false);
      }
      return;
    }
    try {
      final messages = await repository.fetchSessionMessages(chatSessionId: sessionId);
      if (state.sessionId == sessionId) {
        state = state.copyWith(messages: messages, historyLoading: false);
      }
    } catch (_) {
      // 拉取失败不影响主对话：清空 loading，保留空消息（用户可重新点开）
      if (state.sessionId == sessionId) {
        state = state.copyWith(historyLoading: false);
      }
    }
  }

  static String _newId() {
    final random = Random.secure();
    return List<int>.generate(8, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

/// 历史列表按 sessionId 去重，**保留后端返回顺序**。
///
/// 不再做客户端重排：后端 his/record/list 的返回顺序本身就是权威顺序
/// （与 Postman / web 一致）。仅去重是为了避免下拉刷新并发时重复追加同一项。
List<SessionSummary> _sortSessions(List<SessionSummary> input) {
  final seen = <String>{};
  final list = <SessionSummary>[];
  for (final s in input) {
    if (s.sessionId.isEmpty) {
      list.add(s); // 无 id 的项直接保留（理论上不会出现）
      continue;
    }
    if (seen.add(s.sessionId)) list.add(s); // 首次出现才保留，实现去重且保序
  }
  return list;
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) => ChatController(ref));
