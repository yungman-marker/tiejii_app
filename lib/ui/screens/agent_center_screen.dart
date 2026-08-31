import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/agent_provider.dart';
import '../../providers/chat_provider.dart';
import '../widgets/side_drawer.dart';
import '../../core/responsive.dart';
import '../widgets/top_bar_action_button.dart';
import '../widgets/top_bar_icons.dart';

/// 智能中心（S4 真实接口）。
/// 顶部分段：推荐 / 全部 / 我的收藏 / 我的
/// 内容：2 列网格卡片，点击进入智能体详情。
class AgentCenterScreen extends ConsumerStatefulWidget {
  const AgentCenterScreen({super.key});
  @override
  ConsumerState<AgentCenterScreen> createState() => _AgentCenterScreenState();
}

class _AgentCenterScreenState extends ConsumerState<AgentCenterScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(agentControllerProvider.notifier).load());
  }

  void _tip(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentControllerProvider);
    final isWide = isDesktop(context);

    return Scaffold(
      drawer: isWide ? null : const SideDrawer(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(isWide),
            SizedBox(height: 8),
            _segments(state.segment),
            SizedBox(height: 8),
            Expanded(child: _body(state)),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool isWide) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          isWide
              ? const SizedBox.shrink()
              : Builder(
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TopBarActionButton(
                      tooltip: '菜单',
                      icon: TopBarIcons.menu(),
                      onPressed: () {
                        Scaffold.of(ctx).openDrawer();
                        if (ref.read(chatControllerProvider).sessions.isEmpty) {
                          ref
                              .read(chatControllerProvider.notifier)
                              .loadSessions(refresh: true);
                        }
                      },
                    ),
                  ),
                ),
          Expanded(
            child: Center(
              child: Text('智能中心',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: TopBarActionButton(
              tooltip: '创建智能体',
              icon: Icon(Icons.add, size: 20, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => _tip('创建智能体：待后端开放'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segments(AgentSegment current) {
    final labels = ['推荐', '全部', '我的收藏', '我的'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final seg = AgentSegment.values[i];
            final on = seg == current;
            return Expanded(
              child: GestureDetector(
                onTap: () =>
                    ref.read(agentControllerProvider.notifier).setSegment(seg),
                child: Container(
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: on
                        ? const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 4)]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: on ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _body(AgentState state) {
    if (state.loading) {
      return Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }
    if (state.error != null) {
      return _empty(icon: Icons.error_outline, title: '加载失败',
          desc: state.error!, onRetry: () =>
          ref.read(agentControllerProvider.notifier).load());
    }

    final list = state.items;
    if (list.isEmpty) {
      final msg = state.segment == AgentSegment.favorite
          ? '还没有收藏的智能体'
          : state.segment == AgentSegment.mine
              ? '你还没有创建智能体'
              : '当前分类下没有已发布的智能体';
      return _empty(
        icon: Icons.smart_toy_outlined,
        title: msg,
        // 文案同步展示真实调用的查询参数
        desc: '接口：POST /ai/chat/agent/center/page\n'
            '参数：${_describeQuery(state.segment)}',
      );
    }

    final isWide = isDesktop(context);
    return RefreshIndicator(
      onRefresh: () => ref.read(agentControllerProvider.notifier).load(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isWide ? 3 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // 158宽 → 150高 = 1.05，刚好贴合"内容最大自然高 ≈ 143dp"，
          // 余下 7dp 被 _AgentCard 内的 Spacer 分散在「头部↔描述↔底部」之间，杜绝底部留白。
          childAspectRatio: 1.05,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) => _AgentCard(
          skill: list[i],
          onTap: () => context.push('/agents/${list[i].id}'),
        ),
      ),
    );
  }

  /// 把当前 segment 翻译成自然语言，给空状态 desc 用。
  String _describeQuery(AgentSegment seg) {
    switch (seg) {
      case AgentSegment.recommend:
        return 'recommendOnly=true（推荐位）';
      case AgentSegment.all:
        return '全部已发布';
      case AgentSegment.favorite:
        return 'ownershipType=FAVORITE（我的收藏）';
      case AgentSegment.mine:
        return 'ownershipType=MINE（我创建的）';
    }
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String desc,
    VoidCallback? onRetry,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Container(
          margin: const EdgeInsets.only(top: 60),
          padding: const EdgeInsets.all(28),
          alignment: Alignment.center,
          child: Column(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 28, color: AppColors.primary),
              ),
              SizedBox(height: 12),
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text(desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6)),
              if (onRetry != null) ...[
                SizedBox(height: 14),
                TextButton(onPressed: onRetry, child: Text('重试')),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.skill, required this.onTap});
  final AgentSkill skill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chips = _chips();
    final contactLine = _contactLine();

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // 卡片 padding 11 = 顶部 / 底部各 11，左右 11
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
            boxShadow: const [
              BoxShadow(color: Color(0x0A0F172A), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          // Column 用 SpaceBetween 模式：三段内容（头部 / 描述+底部）贴顶/贴底，
          // 中间 Spacer 把任何剩余高度吃掉，杜绝"底部大块留白"。
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 头部：图标 + 名称/chips + 互动 ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _avatar(context),
                  SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          skill.name.isEmpty ? '未命名智能体' : skill.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: skill.name.isEmpty
                                ? AppColors.danger
                                : Theme.of(context).colorScheme.onSurface,
                            height: 1.15,
                          ),
                        ),
                        if (chips.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            chips.take(2).map((c) => c.label).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 4),
                  _interactions(context),
                ],
              ),

              // Spacer 吃掉中间多余的高度，
              // 不管内容长短，描述和底部都会贴到卡片下半部，底部不留空白
              const Spacer(),

              // ── 描述（≤2 行） ──
              Text(
                skill.description.isEmpty ? '暂无描述' : skill.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),

              SizedBox(height: 6),

              // ── 底部：联系人 · 单位 / N 人用过 ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contactLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (skill.useCount > 0) ...[
                    Icon(Icons.bar_chart_outlined,
                        size: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    SizedBox(width: 2),
                    Text('${skill.useCount} 人用过',
                        style: TextStyle(
                            fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),

              // 诊断：name 兜底命中时把后端原始 keys 列出来
              if (skill.name.isEmpty && (skill.debugKeys ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ ${skill.debugKeys}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9.5, color: AppColors.danger, height: 1.3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 派生数据 =====

  /// 渲染用的 2 个 chip 标签：领域 + 模式（thirdParty 优先，缺则用 agentMode）。
  List<_ChipData> _chips() {
    final out = <_ChipData>[];
    final dn = skill.domainName;
    if (dn != null && dn.isNotEmpty) out.add(_ChipData(dn, false));
    final tn = skill.thirdPartyModeName;
    if (tn != null && tn.isNotEmpty) {
      out.add(_ChipData(tn, true));
    } else {
      final am = skill.agentModeName;
      if (am != null && am.isNotEmpty) out.add(_ChipData(am, true));
    }
    return out;
  }

  /// 联系人 · 单位（如「陈强 · 铁四院」），缺单位时只显示联系人。
  String _contactLine() {
    final name = skill.contactName;
    final unit = skill.contactUnit;
    if (name == null && unit == null) return '铁骥大模型';
    if (name == null || name.isEmpty) return unit ?? '铁骥大模型';
    if (unit == null || unit.isEmpty) return name;
    return '$name · $unit';
  }

  // ===== 子组件 =====

  Widget _avatar(BuildContext context) {
    final url = skill.displayIcon;
    final hasImg = url != null && url.isNotEmpty;
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImg
          ? Image.network(url,
              width: 36, height: 36, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialFallback(context))
          : _initialFallback(context),
    );
  }

  Widget _initialFallback(BuildContext context) {
    final ch = skill.name.isNotEmpty ? skill.name[0] : '?';
    return Center(
      child: Text(ch,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _chip(BuildContext context, String label, bool soft) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: soft ? AppColors.primarySoft : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          color: soft ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }

  /// 右上角：点赞数 + 收藏小标。
  Widget _interactions(BuildContext context) {
    final liked = skill.liked;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          liked ? Icons.thumb_up : Icons.thumb_up_outlined,
          size: 12,
          color: liked ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: 2),
        Text('${skill.likeCount}',
            style: TextStyle(
              fontSize: 10,
              color: liked ? AppColors.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            )),
        if (skill.favorite) ...[
          SizedBox(width: 6),
          Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFC107)),
        ],
      ],
    );
  }
}

class _ChipData {
  const _ChipData(this.label, this.soft);
  final String label;
  final bool soft; // true=蓝色 soft；false=灰色 soft
}
