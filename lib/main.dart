import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 启动即恢复本地 JWT，避免每次冷启动重新登录
  await TokenStore.instance.load();
  runApp(const ProviderScope(child: TieJiApp()));
}
