import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/agent_provider.dart';
import '../../providers/chat_provider.dart';

/// 智能体详情（S4 真实接口：GET /ai/chat/skills/{id}）。
class AgentDetailScreen extends ConsumerWidget {
  const AgentDetailScreen({super.key, required this.agentId});
  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(agentDetailProvider(agentId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('智能体', style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: detail.when(
        loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
                const SizedBox(height: 12),
                Text('加载失败：$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                const SizedBox(height: 14),
                FilledButton(onPressed: () => ref.refresh(agentDetailProvider(agentId)),
                    child: const Text('重试')),
              ],
            ),
          ),
        ),
        data: (skill) => _build(context, ref, skill),
      ),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref, AgentSkill? skill) {
    final name = skill?.name ?? '智能体';
    final desc = skill?.description ?? '';
    final greeting = skill?.greeting;
    final cases = skill?.useCases ?? const <String>[];
    final avatar = skill?.avatarUrl;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      children: [
        Center(
          child: Container(
            width: 72, height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F7DF9), Color(0xFF8B5CF6), Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: avatar != null && avatar.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(avatar,
                        width: 72, height: 72, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(name.isNotEmpty ? name[0] : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                    ),
                  )
                : Text(name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.6)),
        ],
        if (skill != null && skill.tags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
            children: skill.tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                      child: Text('#$t', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                    ))
                .toList(),
          ),
        ],
        if (greeting != null && greeting.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('开场白', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(greeting, style: const TextStyle(fontSize: 12.5, height: 1.6)),
              ],
            ),
          ),
        ],
        if (cases.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('常用场景', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ...cases.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider)),
                child: Text(c, style: const TextStyle(fontSize: 12.5, height: 1.5)),
              )),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity, height: 46,
          child: FilledButton.icon(
            onPressed: () {
              // 锁定当前智能体 → 进入新对话；
              // turns:stream body 里的 execution.agentId 取自 state.agentId。
              if (skill == null) return;
              ref
                  .read(chatControllerProvider.notifier)
                  .setAgent(skill.id, skill.name);
              context.go('/chat');
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('开始对话'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
