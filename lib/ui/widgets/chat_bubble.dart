import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

/// 单条消息气泡。
///
/// - 用户：右侧主色气泡
/// - 助手：左侧白色卡片气泡，流式中使用打字机追加；
///   完成后展示一排纯图标操作条：复制 / 重新生成 / 朗读 / 分享
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onRegenerate,
    this.onCopy,
    this.isPlaying = false,
    this.onRead,
    this.onShare,
  });

  final ChatMessage message;
  final VoidCallback? onRegenerate;
  final VoidCallback? onCopy;
  /// 是否正在朗读本条消息（决定底部"朗读"按钮的图标与 tooltip：
  /// true 显示语音播放中的图标 + "停止朗读"，false 显示三角播放图标 + "朗读"）。
  final bool isPlaying;
  final VoidCallback? onRead;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: isUser ? _buildUserBubble() : _buildAssistantBlock(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF3FE),
        borderRadius: BorderRadius.circular(AppRadius.bubble),
      ),
      child: Text(
        message.content,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _buildAssistantBlock() {
    final streaming = message.status == MessageStatus.streaming;
    final waiting = streaming && message.content.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 思考过程（thinkEnable 时展示）
        if (message.thinking != null && message.thinking!.isNotEmpty)
          _buildThinking(),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.bubble),
          ),
          child: waiting
              ? const Text(
                  '思考中…',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                )
              : _renderMarkdown(
                  message.content,
                  const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
        ),

        // 完成后的操作条（纯图标：复制 / 重新生成 / 朗读 / 分享）
        if (!streaming && message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionIcon(
                icon: _svgIcon('assets/icons/copy.svg'),
                tooltip: '复制',
                onTap: onCopy,
              ),
              const SizedBox(width: 4),
              _ActionIcon(
                icon: _svgIcon('assets/icons/refresh.svg'),
                tooltip: '重新生成',
                onTap: onRegenerate,
              ),
              const SizedBox(width: 4),
              _ActionIcon(
                icon: isPlaying
                    ? const _PlayingIcon()
                    : _svgIcon('assets/icons/play.svg'),
                tooltip: isPlaying ? '停止朗读' : '朗读',
                onTap: onRead,
              ),
              const SizedBox(width: 4),
              _ActionIcon(
                icon: _svgIcon('assets/icons/share.svg'),
                tooltip: '分享',
                onTap: onShare,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildThinking() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '思考过程',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message.thinking!,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 气泡底部的纯图标操作按钮。
///
/// - 28×28 触控区，图标 16，居中
/// - 灰底文字色（AppColors.textTertiary），与"复制 / 重新生成"旧胶囊色一致
/// - Tooltip 长按 / 鼠标悬停时显示「复制 / 重新生成 / 朗读 / 分享」字样
/// - 选中淡灰圆形水波（InkWell borderRadius 16）
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(child: icon),
        ),
      ),
    );
  }
}

/// 单色 SVG 图标（着色为 textTertiary，16 尺寸）。
Widget _svgIcon(String asset) {
  return SvgPicture.asset(
    asset,
    width: 16,
    height: 16,
    colorFilter:
        const ColorFilter.mode(AppColors.textTertiary, BlendMode.srcIn),
  );
}

/// 朗读进行中的动态图标：5 条**蓝色**竖线按 sin 错相位脉动，
/// 模拟"声波上下跳动"的视觉效果。停止朗读后由父级换回静态 play.svg。
///
/// - 用 `CustomPainter` 重画（`flutter_svg` 不支持 SMIL `<animate>`）；
/// - 5 条竖线全部 brandBlue 染色，左右镜像错相位 → 中间先高再回落；
/// - AnimationController 1.2s / 循环，`dispose()` 释放避免泄漏。
class _PlayingIcon extends StatefulWidget {
  const _PlayingIcon({this.color = AppColors.brandBlue});

  final Color color;

  @override
  State<_PlayingIcon> createState() => _PlayingIconState();
}

class _PlayingIconState extends State<_PlayingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            size: const Size(16, 16),
            painter: _VoicePlayingPainter(_ctrl.value, widget.color),
          ),
        ),
      ),
    );
  }
}

/// 「语音播放中」声波图标绘制器：5 条竖线，中心对齐，
/// 高度按 sin(t * 2π + phase_i) 在 [基础×0.55, 基础×1.0] 间脉动。
class _VoicePlayingPainter extends CustomPainter {
  _VoicePlayingPainter(this.t, this.color);

  /// 0..1 循环相位。
  final double t;

  /// 竖线颜色（默认 brandBlue）。
  final Color color;

  // —— 5 条竖线的几何参数（按原 voice_playing.svg viewBox=1024 的比例）：
  // 从左到右：基础高度、中心 X。中间最长，向左右两侧逐级变短、变窄。
  static const _bases = <double>[184, 307, 491, 307, 184];
  static const _centers = <double>[143, 266, 512, 758, 881];
  static const _width = 60.0; // 单条宽度（像素，按 viewBox）
  static const _centerY = 512.0; // viewBox 中心 Y

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.width / 1024;
    final paint = Paint()..color = color;
    for (var i = 0; i < _bases.length; i++) {
      // 中心 0，左右对称 ±0.6π
      final phase = (i - 2) * 0.6;
      final amp = 0.5 + 0.5 * math.sin(t * 2 * math.pi + phase);
      final h = _bases[i] * (0.55 + 0.45 * amp);
      final x = _centers[i] - _width / 2;
      final y = _centerY - h / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * scale, y * scale, _width * scale, h * scale),
          Radius.circular(_width * scale / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoicePlayingPainter old) =>
      old.t != t || old.color != color;
}

// ════════════════════════════════════════════════════════════════════
// 轻量 markdown 渲染（标题 / 列表 / 加粗）
// ════════════════════════════════════════════════════════════════════
//
// 故意不引 `flutter_markdown`：截图里后端只返 `# / ## / ###` 标题、
// `-` / `*` 列表项、`**加粗**` 这三类语法，自己写够用。
// 流式打字机下每次增量都会重解析，正则足够快（<1ms）。
// ════════════════════════════════════════════════════════════════════

enum _MdKind { heading, listItem, paragraph }

class _MdBlock {
  _MdBlock(this.kind, this.text, [this.headingLevel = 0]);
  factory _MdBlock.heading(String t, int level) =>
      _MdBlock(_MdKind.heading, t, level);
  factory _MdBlock.listItem(String t) => _MdBlock(_MdKind.listItem, t);
  factory _MdBlock.paragraph(String t) => _MdBlock(_MdKind.paragraph, t);

  final _MdKind kind;
  final String text;
  final int headingLevel;
}

/// 把 markdown 源切成块（标题 / 列表 / 段落）。
/// - 连续非空行合并为同一段（除非开头匹配 `###` / `##` / `#` / `*` / `-`）；
/// - 空行 = 段落分隔。
List<_MdBlock> _splitMarkdown(String src) {
  final lines = src.split('\n');
  final blocks = <_MdBlock>[];
  final para = <String>[];

  void flushPara() {
    if (para.isEmpty) return;
    final joined = para.join('\n');
    para.clear();
    if (joined.trim().isNotEmpty) {
      blocks.add(_MdBlock.paragraph(joined));
    }
  }

  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      flushPara();
      continue;
    }
    final h = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
    if (h != null) {
      flushPara();
      blocks.add(_MdBlock.heading(h.group(2)!.trim(), h.group(1)!.length));
      continue;
    }
    final li = RegExp(r'^[\*\-]\s+(.+)$').firstMatch(line);
    if (li != null) {
      flushPara();
      blocks.add(_MdBlock.listItem(li.group(1)!));
      continue;
    }
    para.add(line);
  }
  flushPara();
  return blocks;
}

/// 行内语法：仅 `**xxx**` 加粗。返回 InlineSpan 列表，供 `Text.rich` 拼接。
List<InlineSpan> _parseInlineMd(String text, TextStyle base) {
  if (!text.contains('**')) {
    return [TextSpan(text: text, style: base)];
  }
  final spans = <InlineSpan>[];
  final reg = RegExp(r'\*\*(.+?)\*\*');
  var last = 0;
  for (final m in reg.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    }
    spans.add(TextSpan(
      text: m.group(1),
      style: base.copyWith(fontWeight: FontWeight.w700),
    ));
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: base));
  }
  return spans;
}

/// 把单块渲染成 InlineSpan（含块尾的 `\n` 分隔）。
InlineSpan _mdBlockToSpan(_MdBlock b, TextStyle base) {
  switch (b.kind) {
    case _MdKind.heading:
      final size = b.headingLevel == 1
          ? 18.0
          : (b.headingLevel == 2 ? 17.0 : 16.0);
      return TextSpan(
        children: [
          ..._parseInlineMd(b.text, base),
          const TextSpan(text: '\n\n'),
        ],
        style: base.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      );
    case _MdKind.listItem:
      return TextSpan(
        children: [
          const TextSpan(text: '· '),
          ..._parseInlineMd(b.text, base),
          const TextSpan(text: '\n'),
        ],
      );
    case _MdKind.paragraph:
      return TextSpan(
        children: [
          ..._parseInlineMd(b.text, base),
          const TextSpan(text: '\n\n'),
        ],
      );
  }
}

/// 公开给 ChatBubble 的渲染入口。
Widget _renderMarkdown(String src, TextStyle base) {
  final blocks = _splitMarkdown(src);
  return Text.rich(
    TextSpan(
      children:
          blocks.map((b) => _mdBlockToSpan(b, base)).toList(growable: false),
    ),
  );
}
