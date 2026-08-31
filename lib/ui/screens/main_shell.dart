import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../widgets/side_drawer.dart';
import 'me_shell_desktop.dart';

/// 主框架：无底部 Tab，模块切换统一走左侧导航。
///
/// - 桌面宽屏（≥900px）：左侧 [SideDrawer] 以**常驻侧栏**形式常驻显示，
///   右侧内容区同屏并排（参考 ChatGPT / Notion 桌面端），不再 overlay 遮罩。
///   - 当路由进入 `/me/*`（个人中心及其子页）时，右侧内容区被 [MeShellDesktop]
///     接管，呈现「面包屑 + 240px 菜单 + 内容」三段式 master-detail 布局。
/// - 移动/窄屏：维持原 [Scaffold] + 各子屏自带的 overlay [Drawer]。
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      // ⚠️ 这里不能直接用 `GoRouterState.of(context).matchedLocation`——
      // 在 ShellRoute 的 builder 上下文里，它读到的是父级路径（即 '/chat'），
      // 而不是当前嵌套的子路径（如 '/me'、'/me/settings'）。这是 go_router 14.x
      // 的行为。要拿到"当前激活的 page 全路径"，必须从 routerDelegate 的
      // currentConfiguration 链尾取 last.matchedLocation。
      final router = GoRouter.of(context);
      final loc = router
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation;
      // /me 区域在桌面端走主区 master-detail（取代 /chat 区域）
      if (loc.startsWith('/me')) {
        return Row(
          children: [
            const SideDrawer(embedded: true),
            Expanded(child: MeShellDesktop(child: child)),
          ],
        );
      }
      return Row(
        children: [
          const SideDrawer(embedded: true),
          Expanded(child: child),
        ],
      );
    }
    return Scaffold(body: child);
  }
}
