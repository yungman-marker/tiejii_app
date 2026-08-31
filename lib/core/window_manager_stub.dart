import 'package:flutter/material.dart';

/// web 端占位实现。
///
/// `window_manager` 仅支持桌面端（Windows / macOS / Linux），不支持 web。
/// Flutter 的 web 构建无法按平台排除插件，且自动生成的插件 registrant 会引用它，
/// 因此 web 构建必须让代码完全不触碰该包——这里提供一个同签名的空实现，
/// 通过 `main.dart` 的条件导入在 web 上生效（桌面端仍用真实包）。
class _StubWindowManager {
  Future<void> ensureInitialized() async {}

  Future<void> setMinimumSize(Size size) async {}
}

/// 与真实包同名的顶层实例，供 main.dart 无条件调用（web 上为空实现）。
final _StubWindowManager windowManager = _StubWindowManager();
