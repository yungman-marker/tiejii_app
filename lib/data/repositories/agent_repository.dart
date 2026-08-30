import '../models/models.dart';
import '../../core/network/api_client.dart';

/// 智能体（智能中心）仓库。
///
/// 接口（实测，2026-08-30 抓 web 端响应确认）：
/// - GET  /ai/chat/agent/center/param
///       返回智能中心下拉选项（visibilityTypes / agentModes / domains /
///       ownershipTypes / statuses / thirdPartyModes / favoriteCount）。
/// - POST /ai/chat/agent/center/page
///       body: {pageNum, pageSize, keyword, agentMode, domainCode, status,
///              visibilityType, agentType, ownershipType, recommendOnly}
///       返回 {total, items:[AgentSkill, ...]}。
class AgentRepository {
  AgentRepository(this._api);

  final ApiClient _api;

  /// 拉取智能中心筛选参数（下拉选项 + 收藏数）。
  Future<AgentCenterParams> fetchCenterParams() async {
    final data = await _api.get<Map<String, dynamic>>(
      '/ai/chat/agent/center/param',
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    return AgentCenterParams.fromJson(data);
  }

  /// 智能体分页列表。
  /// - [recommendOnly]  推荐 tab=true；其余 tab=false。
  /// - [ownershipType]  "MINE"=我的 / "FAVORITE"=我的收藏 / ""=全部。
  /// - [agentMode]      "INTERNAL" / "EXTERNAL" / ""=全部。
  /// - 其余 [keyword]/[domainCode]/[status]/[visibilityType]/[agentType] 同名透传。
  Future<AgentPage> fetchAgentPage({
    int pageNum = 1,
    int pageSize = 30,
    String keyword = '',
    String agentMode = '',
    String domainCode = '',
    String status = '',
    String visibilityType = '',
    String agentType = '',
    String ownershipType = '',
    bool recommendOnly = false,
  }) async {
    final body = <String, dynamic>{
      'pageNum': pageNum,
      'pageSize': pageSize,
      'keyword': keyword,
      'agentMode': agentMode,
      'domainCode': domainCode,
      'status': status,
      'visibilityType': visibilityType,
      'agentType': agentType,
      'ownershipType': ownershipType,
      'recommendOnly': recommendOnly,
    };
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/chat/agent/center/page',
      body: body,
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );

    final rawItems = data?['items'] ?? data?['records'] ?? data?['list'];
    final list = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(AgentSkill.fromJson)
            .toList(growable: false)
        : const <AgentSkill>[];
    final total = (data?['total'] as num?)?.toInt() ?? list.length;
    return AgentPage(
      items: list,
      total: total,
      hasMore: list.length >= pageSize,
    );
  }

  /// 智能体详情（保持原 `/ai/chat/skills/{id}` 路径，与详情页入口一致）。
  /// 实际返回字段对齐 center/page（包含 agentName 等）。
  Future<AgentSkill?> fetchSkillDetail(String id) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/ai/chat/skills/$id',
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    return data == null ? null : AgentSkill.fromJson(data);
  }
}
