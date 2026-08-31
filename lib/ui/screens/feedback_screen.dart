import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/feedback_provider.dart';
import '../widgets/file_picker_helper.dart';

/// 意见反馈 / 回复（/me/feedback，真实接口）。
/// - 我要反馈：5 星评分 + 问题类型 chips + 反馈内容 + 图片上传 + 提交反馈
/// - 意见回复：我提交的反馈列表（带状态 / 官方回复）
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(feedbackControllerProvider.notifier).load());
  }

  void _tip(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedbackControllerProvider);
    final isWide = isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        leading: isWide
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => context.pop(),
              ),
        title: const Text('意见反馈'),
        centerTitle: true,
      ),
      body: SafeArea(bottom: false, child: _buildBody(context, state)),
    );
  }

  /// 主体内容。
  Widget _buildBody(BuildContext context, FeedbackState state) => Column(
        children: [
          _Segments(
            tab: state.tab,
            replyCount: state.submitted.length,
            onChanged: (i) =>
                ref.read(feedbackControllerProvider.notifier).setTab(i),
          ),
          Expanded(
            child: state.tab == 0
                ? _SubmitForm(
                    key: const ValueKey('submit-form'),
                    onSubmit: (payload) => _doSubmit(payload),
                    onTip: _tip,
                  )
                : _ReplyList(
                    key: const ValueKey('reply-list'),
                    items: state.submitted,
                    loading: state.loading,
                    error: state.error,
                    onRefresh: () =>
                        ref.read(feedbackControllerProvider.notifier).load(),
                  ),
          ),
        ],
      );

  Future<void> _doSubmit(_SubmitPayload payload) async {
    final controller = ref.read(feedbackControllerProvider.notifier);
    // 取接口拉到的第一条作为兜底 code；接口未就绪时直接把 chip 名称透传。
    final setting = ref.read(feedbackControllerProvider).setting;
    String? fallbackCode;
    if (setting.questionTypes.isNotEmpty) {
      // 优先按名称匹配
      for (final o in setting.questionTypes) {
        if (o.name == payload.qType) {
          fallbackCode = o.code;
          break;
        }
      }
      fallbackCode ??= setting.questionTypes.first.code;
    }
    final messenger = ScaffoldMessenger.of(context);
    final ok = await controller.submit(
      questionTypeCode: fallbackCode ?? payload.qType,
      answerTypeCode: '',
      content: payload.content,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok
            ? '反馈已提交，感谢支持'
            : (ref.read(feedbackControllerProvider).error ?? '提交失败')),
        behavior: SnackBarBehavior.floating,
      ));
  }
}

// ============================================================================
// 通用组件
// ============================================================================

class _Segments extends StatelessWidget {
  const _Segments({
    required this.tab,
    required this.replyCount,
    required this.onChanged,
  });
  final int tab;
  final int replyCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = ['我要反馈', '意见回复'];
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: List.generate(labels.length, (i) {
          final on = i == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 24),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: on
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        if (i == 1 && replyCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text('($replyCount)',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.error,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    height: 2.5,
                    width: 22,
                    decoration: BoxDecoration(
                      color: on ? scheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// 我要反馈（提交表单）
// ============================================================================

class _SubmitPayload {
  const _SubmitPayload({required this.rating, required this.qType, required this.content});
  final int rating;
  final String qType;
  final String content;
}

class _SubmitForm extends StatefulWidget {
  const _SubmitForm({super.key, required this.onSubmit, required this.onTip});
  final ValueChanged<_SubmitPayload> onSubmit;
  final void Function(String) onTip;

  @override
  State<_SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends State<_SubmitForm> {
  int _rating = 4;
  String _qType = '功能建议';
  final _contentCtrl = TextEditingController();
  PickedFile? _image;
  bool _submitting = false;

  static const _qTypes = ['功能建议', '回答质量', '崩溃卡顿', '界面问题', '其他'];

  String get _ratingText {
    switch (_rating) {
      case 1:
        return '很不好用';
      case 2:
        return '还需要改进';
      case 3:
        return '基本满足';
      case 4:
        return '很好用，还有提升空间';
      case 5:
        return '非常满意';
    }
    return '';
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final f = await pickFile(extensions: const ['png', 'jpg', 'jpeg', 'webp']);
      if (f == null) return;
      setState(() => _image = f);
    } catch (e) {
      widget.onTip('当前平台暂不支持选择文件');
    }
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      widget.onTip('请填写反馈内容');
      return;
    }
    setState(() => _submitting = true);
    try {
      widget.onSubmit(_SubmitPayload(
        rating: _rating,
        qType: _qType,
        content: '$_ratingText\n\n$content',
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        _ratingCard(),
        const SizedBox(height: 12),
        _contentCard(),
        const SizedBox(height: 12),
        _imageCard(),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 16),
          child: Text('可上传截图帮助我们定位问题（选填）',
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
        ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('提交反馈',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _ratingCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          Text('系统使用体验如何？',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 30,
                    color: filled
                        ? const Color(0xFFF59E0B)
                        : scheme.onSurfaceVariant,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(_ratingText,
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _contentCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text('问题类型',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _qTypes.map((t) {
              final selected = t == _qType;
              return GestureDetector(
                onTap: () => setState(() => _qType = t),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: selected
                            ? scheme.primary
                            : scheme.outline),
                  ),
                  child: Text(t,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? scheme.onPrimary
                              : scheme.onSurface)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentCtrl,
            minLines: 3,
            maxLines: 5,
            style: TextStyle(color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: '欢迎说说你想法…\n例如：希望知识库搜索支持语音输入',
              hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 13, height: 1.5),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageCard() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: _pickImage,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: scheme.outline,
                    width: 1,
                    style: BorderStyle.solid),
              ),
              child: Icon(Icons.add,
                  size: 26, color: scheme.onSurfaceVariant),
            ),
          ),
          if (_image != null) ...[
            const SizedBox(width: 10),
            _imageThumb(_image!),
          ],
        ],
      ),
    );
  }

  Widget _imageThumb(PickedFile f) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            Uint8List.fromList(f.bytes),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 72,
              height: 72,
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(Icons.image_outlined,
                  size: 24, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => setState(() => _image = null),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.close, size: 12, color: scheme.onError),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 意见回复（已提交列表）
// ============================================================================

class _ReplyList extends StatelessWidget {
  const _ReplyList({
    super.key,
    required this.items,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });
  final List<FeedbackItem> items;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.primary));
    }
    if (error != null && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: 10),
            Text(error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRefresh, child: const Text('重试')),
          ]),
        ),
      );
    }
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.feedback_outlined,
                      size: 28, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                const Text('暂无反馈记录',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: items.map((f) => _card(f, context)).toList(),
      ),
    );
  }

  Widget _card(FeedbackItem f, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answered = f.replied;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusTag(answered ? '已回复' : '待回复',
                  answered ? AppColors.success : const Color(0xFFEA8A1B)),
              if (f.createTime != null) ...[
                const SizedBox(width: 8),
                Text(f.createTime!,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
              const Spacer(),
              Icon(Icons.chevron_right,
                  size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          Text(f.content,
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurface, height: 1.6)),
          if (answered && f.answer != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.support_agent,
                        size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('官方回复 · ${f.replyTime ?? f.createTime ?? ''}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success)),
                  ]),
                  const SizedBox(height: 4),
                  Text(f.answer!,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          height: 1.6)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
