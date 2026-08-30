import 'package:flutter/material.dart';

/// 顶栏统一风格按钮容器。
///
/// 视觉规范：
///  - 36×36 圆形浅灰背景（默认 `#F5F6F8`，按下 `#E5E6E8`）
///  - 内部图标由 `icon` 决定（推荐传 TopBarIcons.* 的 SVG Widget，默认 20px）
///  - InkWell 圆形水波点击反馈（半径 18）
///
/// 用法：
/// ```dart
/// TopBarActionButton(
///   tooltip: '菜单',
///   icon: TopBarIcons.menu(),
///   onPressed: () => Scaffold.of(ctx).openDrawer(),
/// )
/// ```
class TopBarActionButton extends StatelessWidget {
  const TopBarActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.background,
  });

  /// 无障碍提示 + 长按提示。
  final String tooltip;

  /// 图标 Widget（推荐 TopBarIcons.*，自带颜色 / 尺寸）。
  final Widget icon;

  /// 点击回调（已自动 disable 在 null 时）。
  final VoidCallback? onPressed;

  /// 容器背景色，默认 `Color(0xFFF5F6F8)`。
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Material(
          color: background ?? const Color(0xFFF5F6F8),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
