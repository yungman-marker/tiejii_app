import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/token_store.dart';

/// 统一业务异常（对应后端 {code,msg} 中 code != 200）。
class ApiException implements Exception {
  const ApiException(this.code, this.message);

  final int code;
  final String message;

  bool get isUnauthorized => code == 401;

  @override
  String toString() => 'ApiException($code): $message';
}

/// REST 客户端。
///
/// 职责：
/// - 统一注入 `X-Client-Type: MOBILE` 与 `Authorization: Bearer <JWT>`
/// - 统一解析 `{code,msg,data,ok}`，code != 200 直接抛 [ApiException]
/// - 401 自动 refresh-token 后重试一次，失败则交由上层重新登录
class ApiClient {
  ApiClient({http.Client? client, TokenStore? tokenStore})
      : _client = client ?? http.Client(),
        _tokenStore = tokenStore ?? TokenStore.instance;

  final http.Client _client;
  final TokenStore _tokenStore;

  /// [hasBody] 为 false 时（如无请求体的 GET）不带 `Content-Type`：
  /// 该头对 GET 无意义，却会在浏览器里触发额外的 CORS 预检。
  Map<String, String> _headers({required bool auth, bool hasBody = true}) {
    final headers = <String, String>{
      if (hasBody) 'Content-Type': 'application/json',
      'X-Client-Type': AppConfig.clientType,
    };
    final token = _tokenStore.accessToken;
    if (auth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<T?> get<T>(
    String path, {
    T? Function(Object? raw)? parser,
    bool auth = true,
  }) =>
      _send<T>('GET', path, parser: parser, auth: auth);

  Future<T?> post<T>(
    String path, {
    Object? body,
    T? Function(Object? raw)? parser,
    bool auth = true,
  }) =>
      _send<T>('POST', path, body: body, parser: parser, auth: auth);

  Future<T?> _send<T>(
    String method,
    String path, {
    Object? body,
    T? Function(Object? raw)? parser,
    bool auth = true,
    bool retried = false,
  }) async {
    final request = http.Request(method, Uri.parse('${AppConfig.apiBase}$path'))
      ..headers.addAll(_headers(auth: auth, hasBody: body != null));
    if (body != null) request.body = jsonEncode(body);

    final streamed =
        await _client.send(request).timeout(AppConfig.requestTimeout);
    final payload = await streamed.stream.bytesToString();

    if (payload.isEmpty) {
      throw ApiException(streamed.statusCode, '服务端返回为空');
    }

    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(streamed.statusCode, '响应格式异常');
    }

    final code = (decoded['code'] as num?)?.toInt() ?? streamed.statusCode;
    if (code != 200) {
      if (code == 401 && auth && !retried && await _refreshToken()) {
        return _send<T>(method, path,
            body: body, parser: parser, auth: auth, retried: true);
      }
      throw ApiException(code, decoded['msg']?.toString() ?? '请求失败（$code）');
    }

    final data = decoded['data'];
    return parser != null ? parser(data) : data as T?;
  }

  Future<bool> _refreshToken() async {
    final refresh = _tokenStore.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.apiBase}/refresh-token'),
            headers: _headers(auth: true),
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(AppConfig.requestTimeout);

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          (decoded['code'] as num?)?.toInt() == 200) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          final access = data['access_token']?.toString();
          if (access != null && access.isNotEmpty) {
            await _tokenStore.saveTokens(
                accessToken: access, refreshToken: refresh);
            return true;
          }
        }
      }
    } catch (_) {
      // 续期失败：交由上层引导重新登录
    }
    return false;
  }

  void dispose() => _client.close();
}
