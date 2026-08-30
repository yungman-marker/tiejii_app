import '../../core/config/app_config.dart';
import '../../core/crypto/rsa_util.dart';
import '../../core/network/api_client.dart';
import '../models/models.dart';

/// 登录结果。
class LoginResult {
  const LoginResult({
    required this.accessToken,
    this.refreshToken,
    this.profile,
    this.permissions = const [],
    this.profileError,
  });

  final String accessToken;
  final String? refreshToken;
  final UserProfile? profile;
  final List<String> permissions;

  /// 资料/权限拉取失败的原因（**不再静默吞掉**）
  final String? profileError;
}

/// 鉴权仓库：公钥获取 → RSA 加密 → 登录 → 拉取用户与权限。
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// GET /auth/publicKey
  Future<String> fetchPublicKey() async {
    final data = await _api.get<Map<String, dynamic>>(
      '/auth/publicKey',
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
      auth: false,
    );
    final key = data?['publicKey']?.toString();
    if (key == null || key.isEmpty) {
      throw const ApiException(500, '获取 RSA 公钥失败');
    }
    return key;
  }

  /// POST /auth/login（密码经 RSA / PKCS1-v1.5 加密后传输）
  Future<LoginResult> login({
    required String userName,
    required String password,
  }) async {
    final publicKey = await fetchPublicKey();
    final encrypted = RsaUtil.encryptToBase64(password, publicKey);

    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {
        'enterpriseName': AppConfig.enterpriseName,
        'userName': userName,
        'password': encrypted,
        'code': '',
        'uuid': '',
        'source': AppConfig.loginSource,
        'clientType': AppConfig.clientType,
      },
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
      auth: false,
    );

    final accessToken = data?['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(20010, '登录失败：服务端未返回 access_token');
    }

    final refreshToken = data?['refresh_token']?.toString();

    // 登录成功后补齐用户资料与权限。
    // 失败**不影响登录本身**，但要把原因带回上层展示——曾因静默吞异常
    // 导致界面误显示"未登录"。
    UserProfile? profile;
    List<String> permissions = const [];
    String? profileError;
    try {
      profile = await fetchProfile();
      permissions = await fetchPermissions();
    } catch (e) {
      profileError = e.toString();
    }

    return LoginResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      profile: profile,
      permissions: permissions,
      profileError: profileError,
    );
  }

  /// GET /system/user/getInfo
  Future<UserProfile?> fetchProfile() async {
    final data = await _api.get<Map<String, dynamic>>(
      '/system/user/getInfo',
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    return data == null ? null : UserProfile.fromJson(data);
  }

  /// POST /system/chat/role/menu/allPermission
  /// 返回 permsSet，用于按权限显隐顶部 / 底部 Tab（与 Web 端一致）。
  Future<List<String>> fetchPermissions() async {
    final data = await _api.post<Map<String, dynamic>>(
      '/system/chat/role/menu/allPermission',
      body: {},
      parser: (raw) => raw is Map<String, dynamic> ? raw : null,
    );
    final perms = data?['permsSet'];
    if (perms is List<dynamic>) {
      return perms.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
