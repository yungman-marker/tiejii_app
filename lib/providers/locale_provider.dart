import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart' show sharedPreferencesProvider;

/// 语言（Locale）持久化：当前仅支持 zh_CN / en_US。
///
/// 启动时在 [main] 里 await SharedPreferences 后 [sharedPreferencesProvider]
/// 注入；之后 [localeProvider] 同步可读。
class LocaleNotifier extends Notifier<Locale?> {
  static const _key = 'tj_locale';

  @override
  Locale? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final tag = prefs.getString(_key);
    if (tag == null) return null; // 跟随系统
    return _parseTag(tag);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, _encodeTag(locale));
    }
  }

  static String _encodeTag(Locale l) => '${l.languageCode}_${l.countryCode ?? ''}';

  static Locale? _parseTag(String tag) {
    final parts = tag.split('_');
    if (parts.isEmpty || parts[0].isEmpty) return null;
    if (parts.length == 1) return Locale(parts[0]);
    return Locale(parts[0], parts[1]);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);
