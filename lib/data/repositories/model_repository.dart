import 'dart:convert';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../models/models.dart';

/// 模型仓库：模型列表 + 移动端默认模型。
class ModelRepository {
  ModelRepository(this._api);

  final ApiClient _api;

  /// POST /ai/chat/model/list
  Future<List<ChatModel>> fetchModels() async {
    final data = await _api.post<List<dynamic>>(
      '/ai/chat/model/list',
      body: {},
      parser: (raw) => raw is List<dynamic> ? raw : null,
    );
    if (data == null) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ChatModel.fromJson)
        .toList();
  }

  /// POST /ai/chat/model/getDefault
  ///
  /// 响应中 `chatModelCode` 是一段 JSON 字符串，形如：
  /// `{"mobile":"2068620425530499073","pc":["2068616013315629058"]}`
  /// 需要二次解析取 `mobile` 字段作为移动端默认模型 id。
  Future<String?> fetchDefaultMobileModelId() async {
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/chat/model/getDefault',
      body: {'clientType': AppConfig.clientType},
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );

    final rawCode = data?['chatModelCode'];
    if (rawCode == null) return null;

    if (rawCode is String) {
      try {
        final decoded = jsonDecode(rawCode);
        if (decoded is Map<String, dynamic>) {
          return decoded['mobile']?.toString();
        }
      } catch (_) {
        return rawCode; // 非 JSON，直接当作模型 id
      }
    }
    return null;
  }
}
