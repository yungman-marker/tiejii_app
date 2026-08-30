import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/chat_provider.dart';
import '../../providers/model_availability_provider.dart';
import '../../providers/model_provider.dart';

/// 模型选择底部面板。
///
/// 依据 `supportThinking` / `inputModel` 标注模型能力，供上层决定
/// 思考开关与图片入口的显隐。
class ModelSheet extends ConsumerWidget {
  const ModelSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelControllerProvider);

    final avail = ref.watch(modelAvailabilityProvider);

    // 实时拉取兜底：从任意入口打开面板时，如果模型列表还没拿到，
    // 就触发一次 load()，确保面板上展示的是最新数据。
    if (state.models.isEmpty && !state.loading && state.error == null) {
      Future.microtask(
        () => ref.read(modelControllerProvider.notifier).load(),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              '选择模型',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              '实测不可用会以红点标注，点击可重试',
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 10),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.models.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text(
                  state.error ?? '暂无可用模型',
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
              ),
            )
          else
            ...state.models.map(
              (model) => _ModelTile(
                model: model,
                selected: model.id == state.selectedId,
                availability:
                    avail.status[model.id] ?? ModelAvailability.unknown,
                reason: avail.reason[model.id],
                onTap: () {
                  ref.read(modelControllerProvider.notifier).select(model.id);
                  ref.read(chatControllerProvider.notifier).setModel(model.id);
                  Navigator.pop(context);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({
    required this.model,
    required this.selected,
    required this.availability,
    this.reason,
    required this.onTap,
  });

  final ChatModel model;
  final bool selected;
  final ModelAvailability availability;
  final String? reason;
  final VoidCallback onTap;

  Color get _dotColor {
    switch (availability) {
      case ModelAvailability.available:
        return Colors.green;
      case ModelAvailability.checking:
        return AppColors.primary;
      case ModelAvailability.unavailable:
        return AppColors.danger;
      case ModelAvailability.unknown:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnavailable = availability == ModelAvailability.unavailable;
    final isChecking = availability == ModelAvailability.checking;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isUnavailable
                ? AppColors.danger
                : (selected ? AppColors.primary : Colors.transparent),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _statusDot(color: _dotColor, pulse: isChecking),
                      Text(
                        model.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (model.isCharge) _buildTag('计费'),
                      if (model.supportThinking) _buildTag('思考'),
                      if (model.supportsImage) _buildTag('图片'),
                      if (isUnavailable) _buildTag('暂不可用', danger: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.code,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (isUnavailable && reason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      reason!,
                      style: const TextStyle(fontSize: 11, color: AppColors.danger),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, {bool danger = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: danger ? AppColors.dangerSoft : AppColors.divider,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: danger ? AppColors.danger : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _statusDot({required Color color, bool pulse = false}) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: color.withAlpha(90),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
