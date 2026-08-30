import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';
import '../data/models/models.dart';
import '../data/repositories/auth_repository.dart';
import 'core_providers.dart';

/// 登录态。
///
/// 注意区分三件事：
/// - [isLoggedIn]：是否持有有效 JWT（**这才是"已登录"的唯一判据**）
/// - [profile]：用户资料，可能因网络/平台限制拉取失败而为空
/// - [profileError]：资料拉取失败的原因，必须暴露出来而不是静默吞掉
class AuthState {
  const AuthState({
    this.accessToken,
    this.account,
    this.profile,
    this.permissions = const [],
    this.loading = false,
    this.error,
    this.profileError,
  });

  final String? accessToken;

  /// 登录时使用的账号名（即使资料拉取失败也一定有值）
  final String? account;
  final UserProfile? profile;
  final List<String> permissions;
  final bool loading;
  final String? error;

  /// 资料/权限拉取失败的原因（不影响已登录状态）
  final String? profileError;

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  /// 展示名：优先昵称 → 账号名 → 空
  String get displayName {
    if (profile != null && profile!.displayName.isNotEmpty) {
      return profile!.displayName;
    }
    return account ?? '';
  }

  AuthState copyWith({
    String? accessToken,
    String? account,
    UserProfile? profile,
    List<String>? permissions,
    bool? loading,
    String? error,
    String? profileError,
    bool clearError = false,
    bool clearProfileError = false,
  }) =>
      AuthState(
        accessToken: accessToken ?? this.accessToken,
        account: account ?? this.account,
        profile: profile ?? this.profile,
        permissions: permissions ?? this.permissions,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        profileError: clearProfileError ? null : (profileError ?? this.profileError),
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._store) : super(const AuthState());

  final AuthRepository _repository;
  final TokenStore _store;

  /// 冷启动恢复：本地已有 JWT 则直接进入主界面。
  Future<void> restore() async {
    final token = _store.accessToken;
    if (token == null || token.isEmpty) return;

    state = state.copyWith(accessToken: token, clearProfileError: true);
    try {
      final profile = await _repository.fetchProfile();
      final permissions = await _repository.fetchPermissions();
      state = state.copyWith(profile: profile, permissions: permissions);
    } catch (e) {
      // 资料拉取失败**不影响已登录状态**，但必须把原因暴露出来，
      // 否则界面会误显示"未登录"（曾经的 bug）。
      state = state.copyWith(profileError: _describe(e));
    }
  }

  /// 把异常转成可读文案。Web 平台多为 CORS/XHR 失败，这里给出针对性提示。
  static String _describe(Object e) {
    if (e is ApiException) return '${e.message}（code ${e.code}）';
    final text = e.toString().toLowerCase();
    if (text.contains('xmlhttprequest') ||
        text.contains('cors') ||
        text.contains('cross-origin')) {
      return '浏览器跨域被拦截（Web 端限制），桌面/移动端不受影响';
    }
    if (text.contains('timeout')) return '请求超时';
    if (text.contains('socket') || text.contains('connection')) {
      return '网络连接失败';
    }
    return e.toString();
  }

  /// 账号密码登录（内部完成：取公钥 → RSA 加密 → 登录 → 存 JWT）。
  Future<bool> login({
    required String userName,
    required String password,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result =
          await _repository.login(userName: userName, password: password);
      await _store.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      state = AuthState(
        accessToken: result.accessToken,
        // 即便资料接口失败，账号名也一定有值，界面不会误显示"未登录"
        account: userName,
        profile: result.profile,
        permissions: result.permissions,
        profileError: result.profileError,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: '登录失败，请检查网络或账号信息');
      return false;
    }
  }

  Future<void> logout() async {
    await _store.clear();
    state = const AuthState();
  }

  /// 权限判断（与 Web 一致：按 permsSet 显隐菜单）
  bool hasPermission(String perm) => state.permissions.contains(perm);
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(tokenStoreProvider),
  );
});
