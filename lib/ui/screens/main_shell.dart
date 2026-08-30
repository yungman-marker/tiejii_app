import 'package:flutter/material.dart';

/// 主框架：无底部 Tab（按设计稿，模块切换统一走「左滑抽屉」）。
///
/// /chat · /agents · /knowledge 三个 ShellRoute 子路由在此壳内切换，
/// 每个子屏各自挂载 [Drawer]（SideDrawer）作为全局导航入口。
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}
