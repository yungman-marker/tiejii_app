import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/chat_provider.dart';
import '../../providers/knowledge_provider.dart';
import '../widgets/file_picker_helper.dart';
import '../widgets/side_drawer.dart';
import '../widgets/top_bar_action_button.dart';
import '../widgets/top_bar_icons.dart';

/// 知识库管理（S5 真实接口：`queryAllDirectoryList`）。
/// 顶栏：返回 + 标题 + 筛选 + 上传
/// 内容：容量卡 + 按 type 过滤的目录树（可展开/折叠）
class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});
  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(knowledgeControllerProvider.notifier).load());
  }

  void _tip(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(knowledgeControllerProvider);
    final uploading = state.busyId == '__upload__';

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SideDrawer(),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _header(),
                _typeSelector(state.type),
                Expanded(child: _body(state)),
              ],
            ),
            if (uploading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        SizedBox(height: 10),
                        Text('上传中…', style: TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          Builder(
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
          const Expanded(
            child: Center(
              child: Text('知识库', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TopBarActionButton(
              tooltip: '筛选',
              icon: const Icon(Icons.tune, size: 20, color: AppColors.textPrimary),
              onPressed: () => _tip('筛选：待后端开放'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: TopBarActionButton(
              tooltip: '上传',
              icon: const Icon(Icons.upload, size: 20, color: AppColors.textPrimary),
              onPressed: _pickAndUpload,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeSelector(int current) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: kKnowledgeTypes.entries.map((e) {
          final on = e.key == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => ref.read(knowledgeControllerProvider.notifier).setType(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: on ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: on ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body(KnowledgeState state) {
    if (state.loading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: 10),
            Text(state.error!, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.read(knowledgeControllerProvider.notifier).load(),
                child: const Text('重试')),
          ]),
        ),
      );
    }

    final filtered = state.filteredRoots;
    final tree = _buildTree(filtered, state);
    return RefreshIndicator(
      onRefresh: () => ref.read(knowledgeControllerProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          _capacityCard(state.capacity),
          const SizedBox(height: 12),
          if (tree.isEmpty)
            _empty()
          else
            ...tree,
        ],
      ),
    );
  }

  /// 递归渲染目录树：展开某目录时，先递归渲染其子目录，再渲染该目录下的文件
  /// （文件来自 /file/list，按需懒加载）。缩进随 depth 递增。
  List<Widget> _buildTree(List<KnowledgeDirectory> roots, KnowledgeState state) {
    final out = <Widget>[];
    void walk(KnowledgeDirectory d, int depth) {
      out.add(_dirTile(d, depth: depth, state: state));
      if (state.expanded.contains(d.id)) {
        for (final c in d.children) walk(c, depth + 1);
        out.addAll(_fileRows(d, depth: depth + 1, state: state));
      }
    }
    for (final r in roots) walk(r, 0);
    return out;
  }

  Widget _capacityCard(KnowledgeCapacity? cap) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.storage_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('已用 ${cap?.usePercent ?? '—'}% · 剩余 ${cap?.remainPercent ?? '—'}%',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('文件数 ${cap?.fileNum ?? '—'}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: LinearProgressIndicator(
              value: _pct(cap?.usePercent),
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  double _pct(String? v) {
    final n = double.tryParse(v?.replaceAll('%', '') ?? '');
    if (n == null) return 0;
    return (n / 100).clamp(0, 1);
  }

  Widget _dirTile(KnowledgeDirectory d, {required int depth, required KnowledgeState state}) {
    final hasChildren = d.hasChildren;
    final expanded = state.expanded.contains(d.id);
    final fallbackName = d.name.isEmpty;
    // 缩进：每深一级加 14dp，最多 3 级；超 3 级直接用最后一级缩进防止越界。
    final indent = depth.clamp(0, 3) * 14.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider)),
      child: ListTile(
        contentPadding: EdgeInsets.fromLTRB(8 + indent, 4, 8, 4),
        leading: SizedBox(
          width: 38, height: 38,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 文件夹主图标（随 type 轻微变深）
              Container(
                width: 38, height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: d.type == 0
                      ? const Color(0xFFFFF7E6)
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  expanded
                      ? Icons.folder_open
                      : Icons.folder,
                  size: 20,
                  color: d.type == 0
                      ? const Color(0xFFD4880E)
                      : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                fallbackName ? '未命名目录' : d.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fallbackName ? AppColors.danger : AppColors.textPrimary,
                ),
              ),
            ),
            if (d.type == 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('共享',
                    style: TextStyle(fontSize: 9, color: Color(0xFFD4880E), fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (hasChildren)
                  Text('${d.children.length} 个子目录',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary))
                else
                  const Text('空目录',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                if ((d.fullPath ?? '').isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(d.fullPath!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                  ),
                ],
              ],
            ),
            if (fallbackName && (d.debugKeys ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '⚠️ 原始字段: ${d.debugKeys}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.danger, height: 1.3),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 160),
            child: const Icon(Icons.expand_more, size: 18, color: AppColors.textTertiary),
          ),
          // 右箭头 = 展开/折叠（子目录 + 该目录下的文件，文件来自 /file/list）
          onPressed: () =>
              ref.read(knowledgeControllerProvider.notifier).toggleExpanded(d.id),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        // 主点击：同右箭头，展开/折叠（恢复「子菜单」树形交互）
        onTap: () =>
            ref.read(knowledgeControllerProvider.notifier).toggleExpanded(d.id),
      ),
    );
  }

  /// 各目录展开后，渲染其下的文件行（来自 /file/list，懒加载）。
  List<Widget> _fileRows(KnowledgeDirectory d, {required int depth, required KnowledgeState state}) {
    final loading = state.loadingDirFiles.contains(d.id);
    final files = state.dirFiles[d.id];
    final total = state.dirFileTotal[d.id] ?? 0;
    if (loading) {
      return [
        Padding(
          padding: EdgeInsets.only(left: depth * 14.0 + 14, top: 6, bottom: 6),
          child: const Row(children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            SizedBox(width: 8),
            Text('加载文件中…', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          ]),
        ),
      ];
    }
    if (files == null || files.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(left: depth * 14.0 + 14, top: 2, bottom: 6),
          child: const Text('暂无文件', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ),
      ];
    }
    final rows = <Widget>[for (final f in files) _fileRow(f, depth: depth)];
    if (total > files.length) rows.add(_viewAllRow(d, total, depth));
    return rows;
  }

  Widget _fileRow(KnowledgeFile f, {required int depth}) {
    final color = _extColor(f.ext);
    final extLabel = f.ext.isEmpty
        ? '?'
        : f.ext.toUpperCase().substring(0, f.ext.length > 4 ? 4 : f.ext.length);
    return Container(
      margin: EdgeInsets.only(left: depth * 14.0, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(extLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
        ),
        title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        subtitle: f.displaySize.isNotEmpty
            ? Padding(padding: const EdgeInsets.only(top: 2),
                child: Text(f.displaySize, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)))
            : null,
        trailing: const Icon(Icons.open_in_new, size: 14, color: AppColors.textTertiary),
        onTap: () => _openFile(f),
      ),
    );
  }

  Widget _viewAllRow(KnowledgeDirectory d, int total, int depth) {
    return Container(
      margin: EdgeInsets.only(left: depth * 14.0, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
        title: Text('查看全部 $total 个文件',
            style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
        onTap: () => context.push(
          '/knowledge/dir?dirId=${Uri.encodeComponent(d.id)}'
          '&name=${Uri.encodeComponent(d.name.isEmpty ? '目录' : d.name)}&type=${d.type}',
        ),
      ),
    );
  }

  Future<void> _openFile(KnowledgeFile f) async {
    final url = f.fileUrl;
    if (url == null || url.isEmpty) {
      _tip('该文件暂无预览链接');
      return;
    }
    // 在 APP 内打开预览（不跳外部浏览器）
    context.push(
      '/file/preview?url=${Uri.encodeComponent(url)}'
      '&name=${Uri.encodeComponent(f.displayName)}'
      '&ext=${Uri.encodeComponent(f.ext)}',
    );
  }

  Color _extColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFE5484D);
      case 'doc':
      case 'docx':
        return const Color(0xFF2D6CDF);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return const Color(0xFF1A9B5B);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFE8833A);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'bmp':
      case 'webp':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _empty() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.folder_open, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          const Text('该知识库暂无目录', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('点击右上角上传按钮添加文件\nPOST /ai/chat/knowledgebase/file/queryAllDirectoryList',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary, height: 1.7)),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    try {
      final picked = await pickFile();
      if (picked == null) return;
      await ref.read(knowledgeControllerProvider.notifier)
          .upload(bytes: picked.bytes, fileName: picked.name);
      _tip('上传成功');
    } catch (e) {
      _tip('选择文件失败：$e');
    }
  }
}
