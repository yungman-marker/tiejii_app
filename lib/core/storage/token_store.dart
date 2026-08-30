import 'package:shared_preferences/shared_preferences.dart';

/// JWT 本地存储。
///
/// 安全约定：仅缓存 token，**绝不保存明文密码**。
/// 生产环境建议将本实现替换为 `flutter_secure_storage`（Keychain / Keystore），
/// 接口保持不变即可平滑升级。
class TokenStore {
  TokenStore._();

  static final TokenStore instance = TokenStore._();

  static const _kAccess = 'tj_access_token';
  static const _kRefresh = 'tj_refresh_token';

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccess);
    _refreshToken = prefs.getString(_kRefresh);
  }

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, accessToken);
    if (refreshToken != null) {
      await prefs.setString(_kRefresh, refreshToken);
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }
}
