// 基础冒烟测试：确认应用能正常构建（替代 Flutter 默认计数器模板）。
//
// 注：真正的交互/接口测试应在后续补充；此处仅保证 `flutter test` 能编译通过。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tiejii_app/app.dart';
import 'package:tiejii_app/providers/theme_provider.dart';

void main() {
  testWidgets('app builds without throwing', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const TieJiApp(),
      ),
    );
    expect(find.byType(TieJiApp), findsOneWidget);
  });
}
