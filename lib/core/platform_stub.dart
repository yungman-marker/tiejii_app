/// web 端占位：web 平台没有 `dart:io`，提供一个同名的 [Platform] 类，
/// 其静态平台字段全为 false，供 `main.dart` 在 web 上编译通过
/// （真实平台判断走 `dart:io`，web 上永远不会进入桌面窗口管理分支）。
class Platform {
  static const bool isWindows = false;
  static const bool isMacOS = false;
  static const bool isLinux = false;
  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isFuchsia = false;
}
