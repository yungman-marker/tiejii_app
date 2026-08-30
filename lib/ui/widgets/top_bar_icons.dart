import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 顶栏图标统一封装（直接渲染项目内 assets/icons/*.svg，零第三方图标库依赖）。
///
/// 为什么不用 Phosphor / Lucide 等图标库：
///  - 这两个库内部都是 `class XxxIconData extends IconData`，
///    在 Dart 3.13+（`IconData` 已被标记为 `final`）下直接编译失败，
///    报错：`The class 'IconData' can't be extended outside of its library
///    because it's a final class`。
///  - 直接用 flutter_svg 渲染你提供的原版 SVG 资源，既绕开编译问题，
///    又能 100% 还原你给的图标样式（且可用 colorFilter 任意染色）。
///
/// 所有方法返回 Widget，直接喂给 TopBarActionButton 的 `icon` 参数。
class TopBarIcons {
  TopBarIcons._();

  static const String _kMenu = 'assets/icons/menu.svg';
  static const String _kVolumeOn = 'assets/icons/volume_on.svg';
  static const String _kVolumeOff = 'assets/icons/volume_off.svg';
  static const String _kNewChat = 'assets/icons/new_chat.svg';
  static const String _kSearch = 'assets/icons/search.svg';

  static ColorFilter _tint(Color color) =>
      ColorFilter.mode(color, BlendMode.srcIn);

  /// 面包菜单（drawer 入口）。
  /// 两条横线：上长下短（左对齐），极简千问 / DeepSeek 风。
  static Widget menu({
    double size = 20,
    Color color = const Color(0xFF1F1F1F),
  }) {
    return SvgPicture.asset(
      _kMenu,
      width: size,
      height: size,
      colorFilter: _tint(color),
    );
  }

  /// 外放声音开启（speaker + 声波）
  static Widget volumeOn({
    double size = 20,
    Color color = const Color(0xFF1F1F1F),
  }) =>
      SvgPicture.asset(
        _kVolumeOn,
        width: size,
        height: size,
        colorFilter: _tint(color),
      );

  /// 外放声音关闭（speaker + 斜杠）
  static Widget volumeOff({
    double size = 20,
    Color color = const Color(0xFF1F1F1F),
  }) =>
      SvgPicture.asset(
        _kVolumeOff,
        width: size,
        height: size,
        colorFilter: _tint(color),
      );

  /// 新增对话（加号）
  static Widget newChat({
    double size = 20,
    Color color = const Color(0xFF1F1F1F),
  }) =>
      SvgPicture.asset(
        _kNewChat,
        width: size,
        height: size,
        colorFilter: _tint(color),
      );

  /// 搜索（放大镜；描边 SVG，colorFilter.srcIn 染成指定色）
  static Widget search({
    double size = 20,
    Color color = const Color(0xFF1F1F1F),
  }) =>
      SvgPicture.asset(
        _kSearch,
        width: size,
        height: size,
        colorFilter: _tint(color),
      );
}
