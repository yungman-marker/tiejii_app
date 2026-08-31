import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式持久化：浅色 / 深色 / 跟随系统。
///
/// 启动时在 [main] 里 `await SharedPreferences.getInstance()` 后由
/// [SharedPreferencesProviderScope] 注入；之后 [themeModeProvider] 同步可读。
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'tj_theme_mode';

  /// main() 已 await 过的 SharedPreferences 单例。
  late final SharedPreferences _prefs;

  @override
  ThemeMode build() {
    _prefs = ref.read(sharedPreferencesProvider);
    final str = _prefs.getString(_key) ?? 'system';
    return _parse(str);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_key, _encode(mode));
  }

  static String _encode(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _parse(String s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// 主入口注册的 [SharedPreferences] 单例（在 main() 里先 await）。
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);
