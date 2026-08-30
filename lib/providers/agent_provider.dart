import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../data/models/models.dart';
import '../data/repositories/agent_repository.dart';
import 'core_providers.dart';

/// 智能体仓库。
final agentRepositoryProvider =
    Provider<AgentRepository>((ref) => AgentRepository(ref.watch(apiClientProvider)));

/// 智能体分段：0=推荐 1=全部 2=我的收藏 3=我的。
enum AgentSegment { recommend, all, favorite, mine }

/// 当前智能中心请求参数（与 `POST /ai/chat/agent/center/page` 字段对齐）。
class AgentQuery {
  const AgentQuery({
    this.pageNum = 1,
    this.pageSize = 30,
    this.keyword = '',
    this.agentMode = '',
    this.domainCode = '',
    this.status = '',
    this.visibilityType = '',
    this.agentType = '',
    this.ownershipType = '',
    this.recommendOnly = false,
  });

  final int pageNum;
  final int pageSize;
  final String keyword;
  final String agentMode;
  final String domainCode;
  final String status;
  final String visibilityType;
  final String agentType;
  final String ownershipType;
  final bool recommendOnly;

  AgentQuery copyWith({
    int? pageNum,
    int? pageSize,
    String? keyword,
    String? agentMode,
    String? domainCode,
    String? status,
    String? visibilityType,
    String? agentType,
    String? ownershipType,
    bool? recommendOnly,
  }) =>
      AgentQuery(
        pageNum: pageNum ?? this.pageNum,
        pageSize: pageSize ?? this.pageSize,
        keyword: keyword ?? this.keyword,
        agentMode: agentMode ?? this.agentMode,
        domainCode: domainCode ?? this.domainCode,
        status: status ?? this.status,
        visibilityType: visibilityType ?? this.visibilityType,
        agentType: agentType ?? this.agentType,
        ownershipType: ownershipType ?? this.ownershipType,
        recommendOnly: recommendOnly ?? this.recommendOnly,
      );

  /// 根据 [segment] 派生「筛选条件」（分页翻 1、字段清空）。
  static AgentQuery forSegment(AgentSegment seg, {int pageSize = 30}) {
    switch (seg) {
      case AgentSegment.recommend:
        return AgentQuery(pageSize: pageSize, recommendOnly: true);
      case AgentSegment.all:
        return AgentQuery(pageSize: pageSize);
      case AgentSegment.favorite:
        return AgentQuery(pageSize: pageSize, ownershipType: 'FAVORITE');
      case AgentSegment.mine:
        return AgentQuery(pageSize: pageSize, ownershipType: 'MINE');
    }
  }
}

/// 智能中心列表状态。
class AgentState {
  const AgentState({
    this.segment = AgentSegment.recommend,
    this.params = const AgentCenterParams(),
    this.items = const [],
    this.total = 0,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  final AgentSegment segment;

  /// 筛选参数（来自 `/agent/center/param`）。
  final AgentCenterParams params;

  /// 当前页 items。
  final List<AgentSkill> items;
  final int total;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String? error;

  AgentState copyWith({
    AgentSegment? segment,
    AgentCenterParams? params,
    List<AgentSkill>? items,
    int? total,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) =>
      AgentState(
        segment: segment ?? this.segment,
        params: params ?? this.params,
        items: items ?? this.items,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class AgentController extends StateNotifier<AgentState> {
  AgentController(this._ref) : super(const AgentState());

  final Ref _ref;

  AgentRepository get _repo => _ref.read(agentRepositoryProvider);

  /// 切换分段 → 重置 query → 重新拉第一页。
  void setSegment(AgentSegment segment) {
    if (segment == state.segment) return;
    state = state.copyWith(
      segment: segment,
      items: const [],
      total: 0,
      hasMore: false,
      clearError: true,
    );
    load();
  }

  /// 首屏：并发拉「筛选参数」+「第一页 items」。
  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    final query = AgentQuery.forSegment(state.segment);
    try {
      final results = await Future.wait([
        _repo.fetchCenterParams(),
        _repo.fetchAgentPage(
          pageNum: query.pageNum,
          pageSize: query.pageSize,
          keyword: query.keyword,
          agentMode: query.agentMode,
          domainCode: query.domainCode,
          status: query.status,
          visibilityType: query.visibilityType,
          agentType: query.agentType,
          ownershipType: query.ownershipType,
          recommendOnly: query.recommendOnly,
        ),
      ]);
      final params = results[0] as AgentCenterParams;
      final page = results[1] as AgentPage;
      state = state.copyWith(
        params: params,
        items: page.items,
        total: page.total,
        hasMore: page.hasMore,
        loading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: _describe(e));
    }
  }

  /// 翻页。
  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.loading) return;
    final nextPage = (state.items.length ~/ 30) + 1;
    state = state.copyWith(loadingMore: true);
    final q = AgentQuery.forSegment(state.segment);
    try {
      final page = await _repo.fetchAgentPage(
        pageNum: nextPage,
        pageSize: q.pageSize,
        ownershipType: q.ownershipType,
        recommendOnly: q.recommendOnly,
      );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        total: page.total,
        hasMore: page.hasMore,
        loadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  static String _describe(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('cors') || t.contains('cross-origin')) {
      return '浏览器跨域被拦截（Web 端限制），桌面/移动端不受影响';
    }
    if (t.contains('timeout')) return '请求超时';
    if (t.contains('socket') || t.contains('connection')) return '网络连接失败';
    return e.toString();
  }
}

final agentControllerProvider =
    StateNotifierProvider<AgentController, AgentState>((ref) => AgentController(ref));

/// 智能体详情（按 id 拉取）。
final agentDetailProvider =
    FutureProvider.autoDispose.family<AgentSkill?, String>((ref, id) {
  return ref.watch(agentRepositoryProvider).fetchSkillDetail(id);
});
