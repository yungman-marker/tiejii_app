import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../models/models.dart';

/// 模型仓库：模型列表。
class ModelRepository {
  ModelRepository(this._api);

  final ApiClient _api;

  /// POST /ai/chat/model/list
  ///
  /// body 带 `clientType`，与 web 前端发出的请求保持一致。
  /// 默认模型不由本仓库单独拉取——web 端根本不调 getDefault，
  /// 而是直接从 list 响应里的 `isDefault` 字段挑默认，
  /// 见 [ModelController._pickDefaultId]。
  Future<List<ChatModel>> fetchModels() async {
    final data = await _api.post<List<dynamic>>(
      '/ai/chat/model/list',
      body: {'clientType': AppConfig.clientType},
      parser: (raw) => raw is List<dynamic> ? raw : null,
    );
    if (data == null) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChatModel.fromJson)
        .toList();
  }

  /// 默认模型不再单独请求 getDefault（web 端根本不调该端点，
  /// 且后端对其 body 严格校验会 500）。默认模型直接从 list 响应里的
  /// `isDefault` 字段取（`ModelController._pickDefaultId`）。
}
