import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 桌面端响应式断点：屏宽 ≥ 该值视为「桌面 / 宽屏」，启用常驻左侧栏布局。
/// 低于该值走移动端 overlay 抽屉。
const double kDesktopBreakpoint = 900.0;

/// 是否桌面宽屏。宽屏下用常驻侧栏，窄屏用左滑抽屉。
///
/// 关键约束（2026-08-31 按用户要求加固）：物理平台为 Android/iOS 时
/// **永远返回 false**，使 APP 构建在编译/运行时物理上不可能走桌面分支
/// （即使屏幕被拉伸到 >900 也不会误判），彻底杜绝「桌面端布局泄漏到 APP 端」。
/// 其余平台（Windows/macOS/Linux/web）仍按屏宽 ≥ 断点判定，桌面行为不变。
bool isDesktop(BuildContext context) {
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
    return false;
  }
  return MediaQuery.of(context).size.width >= kDesktopBreakpoint;
}

/// 内容区最大宽度（桌面端聊天 / 列表居中限宽，避免宽屏被拉散）。
const double kContentMaxWidth = 1000.0;
