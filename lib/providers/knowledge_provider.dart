import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../data/models/models.dart';
import '../data/repositories/knowledge_repository.dart';
import 'core_providers.dart';

/// 知识库 type：1=个人 2=企业 0=共享（来自分享）。
///
/// 真实接口（queryAllDirectoryList）返回的根目录 `type` 实际是 0/1/2：
///   - type=1 → 个人知识库
///   - type=2 → 企业知识库
///   - type=0 → 共享知识库（来自分享的知识库）
/// 没有"招标"分类（用户 2026-08-30 确认分类里没有招标知识库）。
const Map<int, String> kKnowledgeTypes = {
  1: '个人知识库',
  2: '企业知识库',
  0: '共享知识库',
};

/// 知识库状态（基于 queryAllDirectoryList 真实接口）。
class KnowledgeState {
  const KnowledgeState({
    this.type = 1,
    this.roots = const [],
    this.capacity,
    this.loading = false,
    this.error,
    this.busyId,
    this.expanded = const {},
    this.dirFiles = const {},
    this.loadingDirFiles = const {},
    this.dirFileTotal = const {},
  });

  /// 当前选中的 type tab（1/2/3）。
  final int type;

  /// 全部根目录（来自 queryAllDirectoryList 一次返回的列表）。
  final List<KnowledgeDirectory> roots;

  /// 容量。
  final KnowledgeCapacity? capacity;

  final bool loading;
  final String? error;

  /// 正在上传的文件占位 id（防重复操作）。
  final String? busyId;

  /// 已展开的目录 id 集合。
  final Set<String> expanded;

  /// 各目录下的文件（dirId -> 文件列表），来自 /file/list。
  /// 仅在目录被展开时按需拉取，避免一次性打爆接口。
  final Map<String, List<KnowledgeFile>> dirFiles;

  /// 正在拉取文件的目录 id 集合。
  final Set<String> loadingDirFiles;

  /// 各目录文件总数（dirId -> total），用于「查看全部 N 个文件」。
  final Map<String, int> dirFileTotal;

  /// 按当前 [type] 过滤后的根目录。
  List<KnowledgeDirectory> get filteredRoots =>
      roots.where((r) => r.type == type).toList(growable: false);

  KnowledgeState copyWith({
    int? type,
    List<KnowledgeDirectory>? roots,
    KnowledgeCapacity? capacity,
    bool? loading,
    String? error,
    String? busyId,
    Set<String>? expanded,
    Map<String, List<KnowledgeFile>>? dirFiles,
    Set<String>? loadingDirFiles,
    Map<String, int>? dirFileTotal,
    bool clearError = false,
    bool clearBusy = false,
    bool clearCapacity = false,
    bool clearDirFiles = false,
  }) =>
      KnowledgeState(
        type: type ?? this.type,
        roots: roots ?? this.roots,
        capacity: clearCapacity ? null : (capacity ?? this.capacity),
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        busyId: clearBusy ? null : (busyId ?? this.busyId),
        expanded: expanded ?? this.expanded,
        dirFiles: clearDirFiles ? const {} : (dirFiles ?? this.dirFiles),
        loadingDirFiles:
            clearDirFiles ? const {} : (loadingDirFiles ?? this.loadingDirFiles),
        dirFileTotal:
            clearDirFiles ? const {} : (dirFileTotal ?? this.dirFileTotal),
      );
}

class KnowledgeController extends StateNotifier<KnowledgeState> {
  KnowledgeController(this._ref) : super(const KnowledgeState());

  final Ref _ref;

  KnowledgeRepository get _repo => _ref.read(knowledgeRepositoryProvider);

  /// 切换顶部 type tab。
  void setType(int type) {
    if (type == state.type) return;
    state = KnowledgeState(
      type: type,
      // 切换 tab 不清空缓存：换回来时立刻有数据；
      // 但 expanded 重置，避免上一次展开状态干扰新 tab。
      expanded: const {},
    );
    load();
  }

  /// 展开/折叠某个目录；展开时若该目录文件未拉取则按需调 /file/list。
  void toggleExpanded(String id) {
    final next = Set<String>.from(state.expanded);
    final willExpand = !next.contains(id);
    if (willExpand) {
      next.add(id);
    } else {
      next.remove(id);
    }
    state = state.copyWith(expanded: next);
    if (willExpand) _ensureDirFiles(id);
  }

  /// 展开目录时按需拉取其下文件（每个目录只调一次 /file/list）。
  void _ensureDirFiles(String id) {
    if (state.dirFiles.containsKey(id) || state.loadingDirFiles.contains(id)) {
      return;
    }
    final dir = _findDir(id);
    if (dir == null) return;
    _loadDirFiles(dir);
  }

  KnowledgeDirectory? _findDir(String id) {
    KnowledgeDirectory? walk(List<KnowledgeDirectory> list) {
      for (final d in list) {
        if (d.id == id) return d;
        final r = walk(d.children);
        if (r != null) return r;
      }
      return null;
    }
    return walk(state.roots);
  }

  Future<void> _loadDirFiles(KnowledgeDirectory d) async {
    state = state.copyWith(loadingDirFiles: {...state.loadingDirFiles, d.id});
    try {
      final page = await _repo.fileList(
        parentId: d.id,
        type: d.type.toString(),
        page: 1,
        pageSize: 20,
      );
      state = state.copyWith(
        dirFiles: {...state.dirFiles, d.id: page.items},
        dirFileTotal: {...state.dirFileTotal, d.id: page.total},
        loadingDirFiles: {...state.loadingDirFiles}..remove(d.id),
      );
    } catch (_) {
      state = state.copyWith(
        loadingDirFiles: {...state.loadingDirFiles}..remove(d.id),
      );
    }
  }

  /// 首屏：并发拉「目录树」+「容量」。
  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true, clearDirFiles: true);
    try {
      final results = await Future.wait([
        _repo.queryAllDirectoryList(),
        _repo.capacity('0'),
      ]);
      final roots = results[0] as List<KnowledgeDirectory>;
      final capacity = results[1] as KnowledgeCapacity;
      state = state.copyWith(
        roots: roots,
        capacity: capacity,
        loading: false,
        clearDirFiles: true,
      );
      // 刷新后保持已展开目录的文件可见（重新拉一次 /file/list）。
      for (final id in state.expanded) _ensureDirFiles(id);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: _describe(e));
    }
  }

  /// 上传文件到当前 type 知识库。
  Future<void> upload({
    required List<int> bytes,
    required String fileName,
  }) async {
    state = state.copyWith(busyId: '__upload__', clearError: true);
    try {
      await _repo.upload(type: state.type, bytes: bytes, fileName: fileName);
      // 上传成功后刷新目录树（接口可能拉回新目录；文件粒度不在树里）
      await load();
    } on ApiException catch (e) {
      state = state.copyWith(busyId: null, error: e.message);
    } catch (e) {
      state = state.copyWith(busyId: null, error: _describe(e));
    }
  }

  static String _describe(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('unimplemented')) return '上传/写操作接口待联调确认';
    if (t.contains('cors') || t.contains('cross-origin')) {
      return '浏览器跨域被拦截（Web 端限制），桌面/移动端不受影响';
    }
    if (t.contains('timeout')) return '请求超时';
    if (t.contains('socket') || t.contains('connection')) return '网络连接失败';
    return e.toString();
  }
}

final knowledgeControllerProvider = StateNotifierProvider<KnowledgeController,
    KnowledgeState>((ref) => KnowledgeController(ref));
