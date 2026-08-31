import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/core_providers.dart';

/// 目录文件列表（S6 真实接口：`POST /ai/chat/knowledgebase/file/list`）。
/// 从知识库目录树点进某个目录后查看其下的文件，支持分页「加载更多」，
/// 点文件后用 url_launcher 打开 path（getMinioUrl 完整预览地址）。
class KnowledgeDirScreen extends ConsumerStatefulWidget {
  const KnowledgeDirScreen({
    super.key,
    required this.dirId,
    required this.dirName,
    required this.type,
  });

  /// 目录 id（file/list 的 parentId）。
  final String dirId;

  /// 目录显示名（仅 UI 标题用）。
  final String dirName;

  /// 目录所属知识库 type（1/2/0，file/list body 的 type 字段，字符串）。
  final String type;

  @override
  ConsumerState<KnowledgeDirScreen> createState() => _KnowledgeDirScreenState();
}

class _KnowledgeDirScreenState extends ConsumerState<KnowledgeDirScreen> {
  List<KnowledgeFile> _items = const [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final page = await ref.read(knowledgeRepositoryProvider).fileList(
            parentId: widget.dirId,
            type: widget.type,
            page: reset ? 1 : _page + 1,
            pageSize: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = page.items;
        } else {
          _items = [..._items, ...page.items];
        }
        _total = page.total;
        if (!reset) _page += 1;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _open(KnowledgeFile f) async {
    final url = f.fileUrl;
    if (url == null || url.isEmpty) {
      _toast('该文件暂无预览链接');
      return;
    }
    // 在 APP 内打开预览（不跳外部浏览器）
    context.push(
      '/file/preview?url=${Uri.encodeComponent(url)}'
      '&name=${Uri.encodeComponent(f.displayName)}'
      '&ext=${Uri.encodeComponent(f.ext)}',
    );
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.dirName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('共 $_total 个文件',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            SizedBox(height: 10),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            SizedBox(height: 12),
            FilledButton(onPressed: () => _load(reset: true), child: Text('重试')),
          ]),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder_open, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(height: 10),
            Text('该目录暂无文件',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          ..._items.map((f) => _fileTile(f)),
          if (_items.length < _total)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: _loadingMore
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                    : TextButton(
                        onPressed: () => _load(reset: false),
                        child: Text('加载更多'),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileTile(KnowledgeFile f) {
    final color = _extColor(f.ext);
    final extLabel = f.ext.isEmpty
        ? '?'
        : f.ext.toUpperCase().substring(0, f.ext.length > 4 ? 4 : f.ext.length);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(extLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ),
        title: Text(f.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (f.displaySize.isNotEmpty)
                Text(f.displaySize,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (f.displaySize.isNotEmpty && f.createTime != null) ...[
                SizedBox(width: 6),
                Text('·',
                    style:
                        TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                SizedBox(width: 6),
              ],
              if (f.createTime != null)
                Expanded(
                  child: Text(f.createTime!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: f.isHandled
                      ? const Color(0x140F766E)
                      : const Color(0x14F59E0B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(f.isHandled ? '已入库' : '处理中',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: f.isHandled
                          ? const Color(0xFF0F766E)
                          : const Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
        ),
        trailing:
            Icon(Icons.open_in_new, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: () => _open(f),
      ),
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
}
