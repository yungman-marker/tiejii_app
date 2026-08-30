import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// 记忆设置（/me/memory）。
/// 顶部：长期记忆开关
/// 中部：记忆保留时间（30天 / 90天 / 永久）
/// 底部：已保存的记忆卡片列表
///
/// 数据为前端展示的 mock，对接真实记忆接口时仅需替换 `_mockMemories` 即可。
class _MemoryItem {
  const _MemoryItem({
    required this.tag,
    required this.time,
    required this.description,
    this.danger = false,
  });
  final String tag;
  final String time;
  final String description;
  final bool danger;
}

const _mockMemories = <_MemoryItem>[
  _MemoryItem(
    tag: '岗位偏好',
    time: '3 天前更新',
    description:
        '用户岗位：项目工程师，常用项目类型为盾构/高速公路扩建，输出偏好图表与数字。',
  ),
  _MemoryItem(
    tag: '对话风格',
    time: '1 周前更新',
    description:
        '偏好简洁、技术性强，附计划表/WBS 的回复；少于 200 字的简答直接给结论。',
  ),
  _MemoryItem(
    tag: '常用项目',
    time: '1 周前更新',
    description:
        '沪宁高速改扩建 TJ-3 标段（持续跟进）；西安地铁 8 号线土建 2 标段（2025.6 已移交）。',
  ),
  _MemoryItem(
    tag: '检索偏好',
    time: '2 周前更新',
    description:
        '优先命中本地知识库；离线时返回内部 FAQ；问答对优先；企业标准 > 行业规范。',
  ),
  _MemoryItem(
    tag: '涉密红线',
    time: '1 个月前更新',
    description: '涉及投标报价/商务合同/工资明细时不上传图片附件到云端。',
    danger: true,
  ),
  _MemoryItem(
    tag: '格式偏好',
    time: '1 个月前更新',
    description: '周报/月报使用统一模板；标题层级 H1-H3；表格优先于列表。',
  ),
];

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  bool _enabled = true;
  String _retention = '90天';
  final Set<int> _deleted = <int>{};

  @override
  Widget build(BuildContext context) {
    final list = _enabled
        ? _mockMemories
            .asMap()
            .entries
            .where((e) => !_deleted.contains(e.key))
            .map((e) => e.value)
            .toList()
        : <_MemoryItem>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text('记忆设置'),
        centerTitle: true,
      ),
      body: SafeArea(bottom: false, child: _buildBody(list)),
    );
  }

  /// 主体内容。
  Widget _buildBody(List<_MemoryItem> list) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                _enableCard(),
                const SizedBox(height: 12),
                _retentionCard(),
                const SizedBox(height: 18),
                _SectionHeader(title: '已保存的记忆', trailing: '${list.length} 条'),
                const SizedBox(height: 8),
                ...List.generate(list.length, (i) {
                  final m = list[i];
                  final originalIndex = _mockMemories.indexOf(m);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MemoryCard(
                      item: m,
                      onApply: () => _tip('已应用到当前对话'),
                      onDelete: () => setState(() => _deleted.add(originalIndex)),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      );

  Widget _enableCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('长期记忆',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text('开启后 AI 会记住你的岗位与偏好，回复更贴合',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                        height: 1.5)),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }

  Widget _retentionCard() {
    const opts = ['30天', '90天', '永久'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('记忆保留时间',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: opts.map((o) {
              final selected = o == _retention;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: selected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setState(() => _retention = o),
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        child: Text(o,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _tip(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(m), behavior: SnackBarBehavior.floating));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(trailing,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.item,
    required this.onApply,
    required this.onDelete,
  });
  final _MemoryItem item;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tagColor = item.danger ? AppColors.danger : AppColors.primary;
    final tagBg = item.danger ? AppColors.dangerSoft : AppColors.primarySoft;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: tagBg, borderRadius: BorderRadius.circular(6)),
                child: Text(item.tag,
                    style: TextStyle(
                        fontSize: 11,
                        color: tagColor,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Text(item.time,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
              const SizedBox(width: 8),
              _iconBtn(Icons.add, onTap: onApply),
              const SizedBox(width: 4),
              _iconBtn(Icons.delete_outline, onTap: onDelete),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.description,
              style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                  height: 1.7)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: AppColors.textTertiary),
      ),
    );
  }
}
