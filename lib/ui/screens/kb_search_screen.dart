import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

/// 智能搜索（S6 真实接口入口）。
/// 热门搜索为固定词；最近搜索本地持久化（shared_preferences）。
class KbSearchScreen extends StatefulWidget {
  const KbSearchScreen({super.key});
  @override
  State<KbSearchScreen> createState() => _KbSearchScreenState();
}

class _KbSearchScreenState extends State<KbSearchScreen> {
  final _ctrl = TextEditingController();
  List<String> _recent = const [];

  static const _kRecent = 'kb_recent_search';
  static const _hot = [
    '施工安全规范',
    '隧道工程',
    '桥梁设计标准',
    '混凝土配比',
    '盾构机操作',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecent) ?? const [];
    if (mounted) setState(() => _recent = list);
  }

  Future<void> _saveRecent(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final next = [q, ..._recent.where((e) => e != q)].take(10).toList();
    await prefs.setStringList(_kRecent, next);
    if (mounted) setState(() => _recent = next);
  }

  void _go(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    _saveRecent(query);
    context.push('/knowledge/results?q=${Uri.encodeComponent(query)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _searchBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('热门搜索', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  ),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _hot.map((label) => _Chip(label: label, onTap: () => _go(label))).toList(),
                  ),
                  SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
                        Text('最近搜索', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (_recent.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove(_kRecent);
                              setState(() => _recent = const []);
                            },
                            child: Text('清空', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
                  if (_recent.isEmpty)
                    const _Empty()
                  else
                    ..._recent.map((label) => _RecentItem(label: label, onTap: () => _go(label))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _go(_ctrl.text),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '搜索知识库 · AI 总结',
                        hintStyle: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          TextButton(
            onPressed: () => _go(_ctrl.text),
            child: Text('搜索', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  const _RecentItem({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
        child: Row(
          children: [
            Icon(Icons.history, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(width: 10),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
            ),
            Icon(Icons.arrow_forward_ios, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Text('暂无最近搜索', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
