import 'dart:io' show Platform
    if (dart.library.html) 'core/platform_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart'
    if (dart.library.html) 'core/window_manager_stub.dart';

import 'app.dart';
import 'core/storage/token_store.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 启动即恢复本地 JWT，避免每次冷启动重新登录
  await TokenStore.instance.load();

  // 桌面端（Windows / macOS / Linux）：限制窗口最小尺寸，避免用户把窗口拖到
  // 过小导致左侧抽屉 + 聊天区内容展示不全。
  // 移动端 / Web 无 window_manager 原生实现，必须跳过（否则抛 MissingPluginException）。
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(900, 640));
  }

  // 主题/语言需要 SharedPreferences，所以一并 await
  // （theme_provider 用 sharedPreferencesProvider 拿到这个实例）
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TieJiApp(),
    ),
  );
}
