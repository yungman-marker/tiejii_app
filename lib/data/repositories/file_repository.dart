import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/storage/token_store.dart';

/// 文件上传仓库。
///
/// 对话附件（图片 / 文件 / 拍照）走多部件上传：
///   POST /file/upload
///
/// 字段约定（前端逆向推断，联调时以实际为准）：
/// - 文件字段名 `file`
/// - 业务字段：`type`（知识库类型，对话场景可省略）、`dirId` 等
///
/// 返回结构不固定，这里统一回传解析后的 Map 供上层按需取用。
class FileRepository {
  FileRepository({http.Client? client, TokenStore? tokenStore})
      : _client = client ?? http.Client(),
        _tokenStore = tokenStore ?? TokenStore.instance;

  final http.Client _client;
  final TokenStore _tokenStore;

  /// 多部件上传。
  /// [bytes] 文件二进制；[fileName] 文件名（含扩展名）；
  /// [fields] 额外业务字段（如 type / dirId）。
  Future<Map<String, dynamic>> upload({
    required List<int> bytes,
    required String fileName,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBase}/file/upload'),
    );
    request.headers['X-Client-Type'] = AppConfig.clientType;
    final token = _tokenStore.accessToken;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (fields != null) request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ));

    final response = await _client.send(request).timeout(AppConfig.requestTimeout);
    final body = await response.stream.bytesToString();
    if (body.isEmpty) {
      throw Exception('上传失败：服务端返回为空（${response.statusCode}）');
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final code = (decoded['code'] as num?)?.toInt() ?? response.statusCode;
      if (code != 200) {
        throw Exception(decoded['msg']?.toString() ?? '上传失败（$code）');
      }
      return decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;
    }
    throw Exception('上传响应格式异常');
  }

  void dispose() => _client.close();
}
