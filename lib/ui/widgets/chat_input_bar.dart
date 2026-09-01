import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import 'quick_entry.dart';

/// 底部输入栏（千问 + DeepSeek 风）：
///  - 上方：AI 工具列表胶囊行（裸的，跟输入框分开，千问风）
///  - 下方：独立的**白底+灰描边大圆角**输入框（DeepSeek 风）：
///      上半：TextField（占据主输入区）
///      下半：左 [深度思考]    右 [＋] [🔊]  → 都是圆形深色背景 + 白色图标
///  - 点 ＋：展开区出现在输入框**下方**（整个输入栏变高、对话上移），
///    拍照/相册/文件三卡片用高度+上移+淡入动画呈现（和 DeepSeek 一致）。
///    卡片是浅灰圆角矩形 + 圆形浅色背景包图标；
///    卡片下方还有一行「仅识别图片中的文字」开关（DeepSeek 底部那一行）。
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.streaming,
    this.onCamera,
    this.onGallery,
    this.onFile,
    this.onVoice,
    this.deepThinking = false,
    this.onToggleDeepThinking,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final bool streaming;

  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onFile;
  final VoidCallback? onVoice;

  final bool deepThinking;
  final ValueChanged<bool>? onToggleDeepThinking;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();

  /// 语音识别（仅移动端初始化；桌面端保持 null，麦克风按钮走 widget.onVoice 兜底）
  stt.SpeechToText? _speech;
  bool _speechAvailable = false;
  bool _listening = false;
  stt.LocaleName? _zhLocale;

  /// ＋ 加号是否展开。
  bool _expanded = false;

  late final AnimationController _expandController;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // 仅在移动端初始化语音识别（Windows 桌面不触碰，避免原生能力缺失导致问题）
    if (!isDesktop(context)) _initSpeech();
  }

  /// 初始化语音识别能力并优选中文 locale。失败（设备不支持）则保持不可用。
  Future<void> _initSpeech() async {
    try {
      final s = stt.SpeechToText();
      final ok = await s.initialize(
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (!mounted) return;
      if (ok) {
        try {
          final locales = await s.locales();
          final zh = locales
              .where((l) => l.localeId.toLowerCase().contains('zh'))
              .toList();
          _zhLocale = zh.isNotEmpty
              ? zh.first
              : (locales.isNotEmpty ? locales.first : null);
        } catch (_) {
          // locale 查询失败不影响基础识别
        }
      }
      if (mounted) {
        setState(() {
          _speech = s;
          _speechAvailable = ok;
        });
      }
    } catch (_) {
      // 不支持则保持 _speech=null / _speechAvailable=false
    }
  }

  @override
  void dispose() {
    _speech?.cancel();
    _controller.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _tip(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );

  /// 麦克风按钮：移动端走语音识别，桌面端走 widget.onVoice 兜底提示。
  Future<void> _toggleVoice() async {
    if (isDesktop(context)) {
      widget.onVoice?.call();
      return;
    }
    if (_speech == null || !_speechAvailable) {
      _tip('当前设备暂不支持语音识别');
      return;
    }
    if (_listening) {
      await _speech!.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    // 开始聆听：收起键盘，避免与语音输入冲突
    FocusScope.of(context).unfocus();
    if (mounted) setState(() => _listening = true);
    try {
      await _speech!.listen(
        onResult: (result) {
          if (!mounted) return;
          final text = result.recognizedWords;
          _controller.text = text;
          _controller.selection =
              TextSelection.fromPosition(TextPosition(offset: text.length));
          if (result.finalResult) {
            setState(() => _listening = false);
          }
        },
        localeId: _zhLocale?.localeId,
        partialResults: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
    }
  }

  void _toggleExpanded() {
    if (widget.streaming) return;
    final willExpand = !_expanded;
    setState(() => _expanded = willExpand);
    // 展开时 forward（滑入），收起时 reverse（滑出）
    if (willExpand) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  void _collapseExpanded() {
    if (_expanded) {
      setState(() => _expanded = false);
      _expandController.reverse();
    }
  }

  /// 流式中显示的「结束」（停止）图标：单色 SVG 着色为文字主色。
  Widget get _stopIcon => SvgPicture.asset(
        'assets/icons/stop.svg',
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface, BlendMode.srcIn),
      );

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final showDeepThink = widget.onToggleDeepThinking != null;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ============ 输入框（高圆角白底 + 灰描边）============
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(26),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // —— 上半：TextField（占满主输入区）——
                    TextField(
                      controller: _controller,
                      minLines: 2,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      onTap: _collapseExpanded,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                      decoration: InputDecoration(
                        hintText: _listening ? '聆听中…请说话' : '发消息或按住说话',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 0, vertical: 4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // —— 下半：左 [深度思考]   右 [＋/×] [🔊] ——
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (showDeepThink)
                          _DeepThinkCapsule(
                            active: widget.deepThinking,
                            onTap: () => widget
                                .onToggleDeepThinking!(!widget.deepThinking),
                          ),
                        const Spacer(),
                        // 右侧：展开态显示 ×；否则 ＋（流式进行中时**不替换** ＋）
                        _IconBtn(
                          icon: _expanded
                              ? Icon(Icons.close,
                                  size: 24, color: scheme.onSurface)
                              : Icon(Icons.add,
                                  size: 24, color: scheme.onSurface),
                          onTap: _expanded ? _collapseExpanded : _toggleExpanded,
                        ),
                        const SizedBox(width: 4),
                        _IconBtn(
                          icon: Icon(
                            _listening ? Icons.mic : Icons.mic_none_outlined,
                            size: 24,
                            color: _listening ? Colors.red : scheme.onSurface,
                          ),
                          onTap: _toggleVoice,
                        ),
                        // 流式中：最右侧**额外**追加「停止输出」按钮（不替换 ＋）。
                        // 输出结束 (widget.streaming=false) 后自动消失。
                        if (widget.streaming) ...[
                          const SizedBox(width: 4),
                          _IconBtn(
                            icon: _stopIcon,
                            onTap: widget.onStop,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // ============ ③ ＋ 展开区：在输入框下方，整体上移+高度增长+淡入 ============
              // 用 AnimatedBuilder 纯 controller 驱动几何（高度增长 + 上移 + 淡入）。
              AnimatedBuilder(
                animation: _expandController,
                builder: (context, child) {
                  final v = _expandController.value;
                  if (v <= 0.001) return const SizedBox.shrink();
                  return ClipRect(
                    child: Transform.translate(
                      offset: Offset(0, (1 - v) * 36), // 从底部 36px 下方向上滑入
                      child: Opacity(
                        opacity: v,
                        child: Container(
                          height: 150 * v, // 展开区整体高度（padding 10 + 卡片 100 + 间距 10 + 文字 20 + 10 富余）
                          padding: const EdgeInsets.only(top: 10),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: _ExpandedBody(
                  onCamera: () {
                    _collapseExpanded();
                    widget.onCamera?.call();
                  },
                  onGallery: () {
                    _collapseExpanded();
                    widget.onGallery?.call();
                  },
                  onFile: () {
                    _collapseExpanded();
                    widget.onFile?.call();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 展开区容器：拍照/相册/文件卡片 + 底部「仅识别图片中的文字」文字行。
class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({
    required this.onCamera,
    required this.onGallery,
    required this.onFile,
  });

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // —— 三卡片：拍照 / 相册 / 文件（图标用项目内 SVG 原图）——
        Row(
          children: [
            Expanded(
              child: _PickupCard(
                iconPath: 'assets/icons/camera.svg',
                label: '拍照',
                onTap: onCamera,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickupCard(
                iconPath: 'assets/icons/gallery.svg',
                label: '相册',
                onTap: onGallery,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickupCard(
                iconPath: 'assets/icons/attachment.svg',
                label: '文件',
                onTap: onFile,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // —— 底部：「仅识别图片中的文字」文字描述（不要 Switch）——
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 5),
            Text(
              '仅识别图片中的文字',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 深度思考胶囊（DeepSeek 同款浅蓝主题）：
///  - 激活（默认开启）：浅蓝底 + 蓝色描边 + 蓝色文字
///  - 关闭：白底 + 灰描边 + 黑色文字
class _DeepThinkCapsule extends StatelessWidget {
  const _DeepThinkCapsule({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  // DeepSeek 同款蓝色主题
  static const _blueFill = Color(0xFFEBF3FF); // 浅蓝底
  static const _blueBorder = Color(0xFFB7D5FF); // 蓝色描边
  static const _blueText = Color(0xFF1A6BFF); // 蓝色文字

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _blueFill : scheme.surfaceContainerHighest,
          border: Border.all(
            color: active ? _blueBorder : scheme.outline,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/deep_thinking.svg',
              width: 15,
              height: 15,
              colorFilter: ColorFilter.mode(
                active ? _blueText : scheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '深度思考',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? _blueText : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DeepSeek 风附件卡片：
///  - 浅灰圆角矩形（背景）
///  - 裸 SVG 图标（不带圆形背景，DeepSeek 同款）
///  - 下方文字标签
class _PickupCard extends StatelessWidget {
  const _PickupCard({
    required this.iconPath,
    required this.label,
    required this.onTap,
  });

  /// 项目内 assets/icons/ 下的 SVG 资源路径。
  final String iconPath;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 裸 SVG 图标，不带圆形背景（DeepSeek 同款）
            SvgPicture.asset(
              iconPath,
              width: 28,
              height: 28,
              colorFilter: ColorFilter.mode(
                scheme.onSurface,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 输入框内按钮（＋ / × / 🔊 / 结束）：无背景，仅图标（DeepSeek 风）。
class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
  });

  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(child: icon),
      ),
    );
  }
}
