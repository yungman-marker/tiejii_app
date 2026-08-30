// 独立诊断脚本：在 Dart VM（无浏览器、无 CORS）跑通真实登录链路，
// 验证 RsaUtil 与 ApiClient 的请求/解析逻辑是否正确。
//
// 运行：dart run tool/api_smoke.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tiejii_app/core/crypto/rsa_util.dart';

const base = 'http://kygl-crcc-tj-ai-front-vue.test.cdcgy-gw.com/backendapi';
const user = 'test1234';
const password = 'Crcc#123';

Map<String, String> headers({String? token}) {
  final h = <String, String>{
    'Content-Type': 'application/json',
    'X-Client-Type': 'MOBILE',
  };
  if (token != null) h['Authorization'] = 'Bearer $token';
  return h;
}

/// 完全复刻 ApiClient._send 的行为
Future<dynamic> send(String method, String path,
    {Object? body, String? token}) async {
  final client = http.Client();
  try {
    final request = http.Request(method, Uri.parse('$base$path'))
      ..headers.addAll(headers(token: token));
    if (body != null) request.body = jsonEncode(body);

    final streamed = await client.send(request);
    final payload = await streamed.stream.bytesToString();
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('响应不是 JSON 对象: ${payload.substring(0, 60)}');
    }
    final code = (decoded['code'] as num?)?.toInt() ?? streamed.statusCode;
    if (code != 200) {
      throw Exception('业务失败 code=$code msg=${decoded['msg']}');
    }
    return decoded['data'];
  } finally {
    client.close();
  }
}

Future<void> main() async {
  print('--- 1) 取公钥 ---');
  final pub = (await send('GET', '/auth/publicKey'))['publicKey'] as String;
  print('公钥长度: ${pub.length}');

  print('--- 2) RSA 加密（RsaUtil）---');
  final encrypted = RsaUtil.encryptToBase64(password, pub);
  print('密文 base64 长度: ${encrypted.length}');

  print('--- 3) 登录 ---');
  final loginData = await send('POST', '/auth/login', body: {
    'enterpriseName': 'crcc',
    'userName': user,
    'password': encrypted,
    'code': '',
    'uuid': '',
    'source': 'jg',
    'clientType': 'MOBILE',
  }) as Map<String, dynamic>;
  final token = loginData['access_token'] as String;
  print('登录成功，token 前16位: ${token.substring(0, 16)}');

  print('--- 4) GET /system/user/getInfo（复刻 fetchProfile）---');
  try {
    final data = await send('GET', '/system/user/getInfo', token: token)
        as Map<String, dynamic>?;
    final u = data?['user'];
    final userMap = u is Map<String, dynamic> ? u : data;
    print('成功! userName=${userMap?['userName']} nickName=${userMap?['nickName']}');
  } catch (e) {
    print('失败: $e');
  }

  print('--- 5) POST /ai/chat/model/list（复刻 fetchModels）---');
  try {
    final list = await send('POST', '/ai/chat/model/list',
        body: {}, token: token);
    print('模型数量: ${(list as List?)?.length}');
  } catch (e) {
    print('失败: $e');
  }
}
