import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/chat_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/model_availability_provider.dart';
import '../../providers/model_provider.dart';
import '../../providers/voice_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/file_picker_helper.dart';
import '../widgets/message_actions.dart';
import '../widgets/side_drawer.dart';
import '../widgets/top_bar_action_button.dart';
import '../widgets/top_bar_icons.dart';
import '../../providers/quick_entry_provider.dart';
import '../widgets/quick_entry.dart';
import '../../core/responsive.dart';
import '../widgets/model_sheet.dart';

/// 顶栏标题硬截断上限：超过该字符数（含中文 1 字 = 1 字符）则截到上限 - 1 + `…`。
/// - mobile 顶栏可用宽度 ≈ 219px，16 号中文每字 ≈ 16px → 约 13 字；
/// - 留 1 字符余地给省略号，避免短标题刚到边界时也变省略号。
const int kAppBarTitleMaxChars = 12;

/// 对话主页（千问 / DeepSeek 交互：空态大字 + 流式打字机 + 停止生成）。
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();

  /// 待发送的附件（已上传 /file/upload）。
  final List<_Attachment> _attachments = [];
  bool _deepThinking = true; // 默认开启（蓝色），关闭后变黑色文字
  /// 当前正在朗读的消息 id（null = 无）。同一时刻最多一条消息在播，
  /// 用于切换气泡底部"朗读"按钮的图标与 tooltip。
  String? _playingMessageId;

  @override
  void initState() {
    super.initState();
    // 监听尺寸/viewInsets 变化（键盘弹起/收起、系统 UI 变化），
    // 在跳转到底部跟随最新消息，避免键盘展开瞬间列表看起来"先上滑再下滑"。
    WidgetsBinding.instance.addObserver(this);
    // 进入即加载模型列表，并把移动端默认模型同步给对话控制器
    Future.microtask(() async {
      await ref.read(modelControllerProvider.notifier).load();
      if (!mounted) return;
      final modelId = ref.read(modelControllerProvider).selectedId;
      ref.read(chatControllerProvider.notifier).setModel(modelId);
    });
    // 兜底：进入页面首帧清掉可能从抽屉搜索框继承来的焦点，
    // 避免键盘在用户尚未点击输入框时自动弹出（仅首帧执行一次）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).unfocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  /// 键盘弹起/收起、系统 UI 变化 → 重新贴底，让最新消息始终可见。
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final availabilityNotice = ref.watch(modelAvailabilityProvider).notice;
    final isWide = isDesktop(context);

    // 消息数量变化时自动滚到底（打字机过程中持续跟随）
    ref.listen<int>(
      chatControllerProvider.select((s) => s.messages.length),
      (_, __) => _scrollToBottom(),
    );

    // 流式「进行中 → 结束」且顶部语音开关开启 → 自动朗读刚完成的助手回复。
    // 仅对状态为 done 的助手消息触发（失败/空响应不朗读；历史加载不触发）。
    // 走 _togglePlay 是为了把"正在播放"的气泡图标也同步切到播放中态。
    ref.listen<bool>(
      chatControllerProvider.select((s) => s.streaming),
      (previous, next) {
        if (previous != true || next != false) return;
        if (!ref.read(voiceOutputEnabledProvider)) return;
        final messages = ref.read(chatControllerProvider).messages;
        if (messages.isEmpty) return;
        final last = messages.last;
        if (!last.isUser &&
            last.status == MessageStatus.done &&
            last.content.trim().isNotEmpty) {
          _togglePlay(last.id, last.content);
        }
      },
    );

    // 移动端主体内容：与 gitee 原版一致，直接全宽 Column，不套 Center/ConstrainedBox。
    // 桌面宽屏才需要"内容居中 + 限制最大宽度"的阅读体验（见下方 body 的 isWide 分支）。
    final bodyChildren = <Widget>[
      Expanded(
        // 移动端：点消息列表/空白区域收回软键盘（iOS 标准 UX）。
        // 桌面端 `onTap: null` → 不抢输入框焦点，桌面行为零变化。
        // `HitTestBehavior.opaque` 让 ListView 之间的空白也命中，
        // 但消息气泡的操作按钮（复制/TTS）通过 gesture arena 仍优先触发。
        child: GestureDetector(
          onTap: isWide ? null : () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: chat.historyLoading
              ? _buildHistoryLoading()
              : (chat.isEmpty ? _buildEmptyState() : _buildMessageList(chat)),
        ),
      ),
      if (chat.error != null) _buildErrorBar(chat.error!),
      if (availabilityNotice != null)
        _buildAvailabilityBanner(availabilityNotice),
      if (_attachments.isNotEmpty) _attachmentChips(),
      ChatInputBar(
        streaming: chat.streaming,
        onSend: _send,
        onStop: () => ref.read(chatControllerProvider.notifier).stop(),
        onCamera: () => _pickAndUpload(
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
          mode: _PickMode.camera,
        ),
        onGallery: () => _pickAndUpload(
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
          mode: _PickMode.gallery,
        ),
        onFile: () => _pickAndUpload(mode: _PickMode.file),
        onVoice: () => _tip('语音输入待接入'),
        deepThinking: _deepThinking,
        onToggleDeepThinking: (v) => setState(() => _deepThinking = v),
      ),
    ];

    return Scaffold(
      drawer: isWide ? null : const SideDrawer(),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        // leading 容器：缩小默认 IconButton padding，让按钮组紧凑
        leadingWidth: 56,
        titleSpacing: 0,
        centerTitle: true,
        leading: isWide
            ? null
            : Builder(
                builder: (innerContext) => Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: TopBarActionButton(
                    tooltip: '菜单',
                    icon: TopBarIcons.menu(),
                    onPressed: () {
                      Scaffold.of(innerContext).openDrawer();
                      if (ref.read(chatControllerProvider).sessions.isEmpty) {
                        ref
                            .read(chatControllerProvider.notifier)
                            .loadSessions(refresh: true);
                      }
                    },
                  ),
                ),
              ),
        // 顶部中间：新对话显示「新对话」，历史对话显示该会话标题
        title: _buildAppBarTitle(chat),
        actions: [
          // 右侧：外放声音开关（SVG 图标 + 统一浅色圆形容器）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Consumer(
              builder: (context, ref, _) {
                final enabled = ref.watch(voiceOutputEnabledProvider);
                return TopBarActionButton(
                  tooltip: enabled ? '关闭外放声音' : '开启外放声音',
                  icon: enabled
                      ? TopBarIcons.volumeOn()
                      : TopBarIcons.volumeOff(),
                  onPressed: () => ref
                      .read(voiceOutputEnabledProvider.notifier)
                      .update((state) => !state),
                );
              },
            ),
          ),
          // 右侧：新增对话（复用 ChatController.newChat）
          // 注：搜索历史对话入口已移到左侧抽屉头部（与 DeepSeek 风格一致）
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: TopBarActionButton(
              tooltip: '新增对话',
              icon: TopBarIcons.newChat(),
              onPressed: () =>
                  ref.read(chatControllerProvider.notifier).newChat(),
            ),
          ),
        ],
      ),
      // 桌面宽屏：内容居中并限制最大宽度（参照桌面端阅读体验）；
      // 移动/窄屏：直接全宽 Column（与 gitee 原版一致）。
      body: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
                child: Column(children: bodyChildren),
              ),
            )
          // 移动端：点空白处收起键盘（iOS 软键盘不会随点击外部自动隐藏）
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(children: bodyChildren),
            ),
    );
  }

  Widget _buildHistoryLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 12),
          Text('正在加载历史对话…',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final chat = ref.watch(chatControllerProvider);
    // 已切换到某个历史会话、但明细为空（该会话本身无消息 / 拉取失败）：
    // 展示会话标题 + 诚实提示，并允许直接继续提问。
    final openedSession = chat.sessionId == null
        ? null
        : chat.sessions
            .where((s) => s.sessionId == chat.sessionId)
            .map((s) => s.title)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);
    if (openedSession != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 44, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.brandBlue, Color(0xFF7C3AED)],
              ).createShader(bounds),
              child: const Text(
                '历史对话',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '已打开会话：$openedSession',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '本会话暂无可展示的历史消息，可直接在此继续向模型提问。',
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    const suggestions = <String>[
      '帮我写一份项目周报',
      '这份施工方案有哪些风险点？',
      '工程量清单计价规则是什么？',
    ];

    return SizedBox(
      width: double.infinity, // 关键：外层 body Column 默认 crossAxisAlignment.center，
      //  SingleChildScrollView 不强制 width 时会缩到内容宽度被居中，
      //  强制 maxWidth 撑满后内部 start 才有意义
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 120, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // —— 大标题（千问风：左对齐 + 单色蓝紫 + 整体下移到 1/3 位置）——
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.brandBlue, Color(0xFF7C3AED)],
            ).createShader(bounds),
            child: const Text(
              '我是铁骥',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // —— 副标题（左对齐）——
          Text(
            '懂工程 更懂你，随时为你答疑解惑',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // —— prompt 卡片：每行一个，宽度自适应不撑满（左对齐，千问同款）——
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: suggestions
                .map(
                  (text) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SuggestionCard(
                      text: text,
                      onTap: () => ref
                          .read(chatControllerProvider.notifier)
                          .send(text),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildMessageList(ChatState chat) {
    // 正常时间顺序渲染：数据本身就是 [最早, ..., 最新]，
    // 所以不需要 reverse——以前 reverse:true 把最新消息抛到屏幕顶部，
    // 看起来就像「AI 回复跑到用户消息前面」。
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      itemCount: chat.messages.length,
      itemBuilder: (context, index) {
        final message = chat.messages[index];
        return ChatBubble(
          message: message,
          onCopy: () => _copy(message.content),
          onRegenerate: () =>
              ref.read(chatControllerProvider.notifier).regenerate(),
          onRead: () => _togglePlay(message.id, message.content),
          onShare: () => _share(message.content),
          isPlaying: _playingMessageId == message.id,
        );
      },
    );
  }

  /// 顶栏标题：新会话显示「新对话」，历史会话显示抽屉里的会话标题。
  /// 单行 + 省略号，避免长标题把顶栏撑高。
  ///
  /// 业务层硬截断：超过 [kAppBarTitleMaxChars] 个字符直接裁到该上限 + `…`。
  /// 不依赖屏幕宽度（mobile/桌面/web 宽度差异大，按字符算更稳）。
  /// 视觉层再叠 `maxLines + ellipsis` + `FittedBox` 兜底，保证极端长标题
  /// 也一定出现省略号而不是把顶栏撑高。
  Widget _buildAppBarTitle(ChatState chat) {
    final raw = chat.sessionId == null
        ? '新对话'
        : chat.sessions
            .where((s) => s.sessionId == chat.sessionId)
            .map((s) => s.title)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => '新对话');
    final title = _clampAppBarTitle(raw ?? '新对话');
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  /// 顶栏标题硬截断：
  /// - 超过 [kAppBarTitleMaxChars] 个字符 → 截到 (上限-1) + `…`
  /// - 用 `String.runes` 按 Unicode code points 截，避免把代理对（emoji）截半。
  static String _clampAppBarTitle(String s) {
    final trimmed = s.trim();
    if (trimmed.runes.length <= kAppBarTitleMaxChars) return trimmed;
    final take = kAppBarTitleMaxChars - 1;
    return String.fromCharCodes(trimmed.runes.take(take)) + '…';
  }

  Widget _buildErrorBar(String error) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        error,
        style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
      ),
    );
  }

  /// 模型不可用提示横幅：引导用户切换模型或重试。
  Widget _buildAvailabilityBanner(String notice) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notice,
              style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(modelAvailabilityProvider.notifier).clearNotice();
              // 宽屏常驻侧栏无 Drawer 可开，直接弹模型面板
              if (isDesktop(context)) {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const ModelSheet(),
                );
              } else {
                Scaffold.of(context).openDrawer();
              }
            },
            child: const Text('切换模型', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _tip('已复制');
  }

  /// 切换"朗读"状态：未在读则开始读、并在气泡上把图标换成"正在播放"；
  /// 已经在读本条则停止、还原图标。自动播放（顶栏外放开关开启时）也走
  /// 同一入口，播放态、按钮态、停止行为集中在一处。
  ///
  /// 状态机：
  /// - `_playingMessageId == messageId`：再点一次 = 停
  /// - 否则：先乐观标位（避免 cancel 触发的旧 onend 把新值误清）→ 调 readAloud
  ///   → 成功则保持标记，失败（非 Web 端）则回退 + 提示
  /// - 自然结束 / 被取消：onend 回调里仅当当前还在读本条时才清掉
  Future<void> _togglePlay(String messageId, String text) async {
    if (text.trim().isEmpty) return;
    if (_playingMessageId == messageId) {
      // 已经在读本条 → 主动停止
      await stopReading();
      if (mounted) setState(() => _playingMessageId = null);
      return;
    }
    // 先标记，再发请求：cancel 触发的旧 onend 会比对"当前是否还是我"，
    // 不会被新值误清
    setState(() => _playingMessageId = messageId);
    final ok = await readAloud(text, onEnd: () {
      if (mounted && _playingMessageId == messageId) {
        setState(() => _playingMessageId = null);
      }
    });
    if (!mounted) return;
    if (!ok && _playingMessageId == messageId) {
      // 朗读失败（非 Web 端没接 TTS SDK，已自动复制到剪贴板）：回退状态 + 提示
      setState(() => _playingMessageId = null);
      _tip('已复制文本，朗读功能仅在 Web 端可用');
    }
  }

  /// 分享助手回复（Web 走 navigator.share 唤起系统面板；失败回退剪贴板）。
  Future<void> _share(String text) async {
    if (text.trim().isEmpty) return;
    final ok = await shareText(text);
    if (!mounted) return;
    if (ok) {
      _tip('已分享');
    } else {
      _tip('分享失败');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // 正常顺序渲染：最新消息在 ListView 末尾，最底部 = maxScrollExtent。
      // 用 jumpTo(maxScrollExtent) 而非 animateTo，避免键盘升降时
      // maxScrollExtent 瞬时错位导致的"先上滑再下滑"动画。
      // 仅当用户已在底部附近时跟随，避免把正向上翻看历史的人强行拉回。
      final pos = _scrollController.position;
      final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
      if (distanceFromBottom > 200) return;
      _scrollController.jumpTo(pos.maxScrollExtent);
    });
  }

  void _tip(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// 发送：把附件名拼到正文前，随消息一起提交（后端 chat 接口以文本承载附件引用）。
  void _send(String text) {
    final content = text.trim();
    if (content.isEmpty && _attachments.isEmpty) return;
    final buffer = StringBuffer();
    if (_attachments.isNotEmpty) {
      buffer.writeln('[附件] ${_attachments.map((a) => a.name).join('、')}');
    }
    if (content.isNotEmpty) buffer.writeln(content);
    ref.read(chatControllerProvider.notifier).send(buffer.toString().trim(),
        thinkEnable: _deepThinking);
    setState(() => _attachments.clear());
  }

  Future<void> _pickAndUpload({
    List<String>? extensions,
    _PickMode mode = _PickMode.file,
  }) async {
    if (!mounted) return;
    try {
      final picked = await pickFile(
        extensions: extensions,
        mode: PickMode.values[mode.index],
      );
      if (picked == null) return;
      if (!mounted) return;
      final result = await ref.read(fileRepositoryProvider).upload(
        bytes: picked.bytes,
        fileName: picked.name,
      );
      if (!mounted) return;
      final id = result['id']?.toString() ?? result['fileId']?.toString();
      setState(() {
        _attachments.add(_Attachment(name: picked.name, id: id));
      });
      _tip(mode == _PickMode.file ? '已上传文件：${picked.name}' : '已上传图片：${picked.name}');
    } catch (e) {
      if (mounted) _tip('上传失败：$e');
    }
  }

  void _removeAttachment(int index) => setState(() => _attachments.removeAt(index));

  Widget _attachmentChips() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (var i = 0; i < _attachments.length; i++)
            Chip(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => _removeAttachment(i),
              label: Text(_attachments[i].name, style: const TextStyle(fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}

class _Attachment {
  const _Attachment({required this.name, this.id});
  final String name;
  final String? id;
}

enum _PickMode { camera, gallery, file }

/// 空态 prompt 卡片：纯文字 + 自适应宽度 + 细边框（千问同款）
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        // 不加 Expanded，让卡片宽度紧贴文字（自适应）
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(color: Theme.of(context).colorScheme.outline, width: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
