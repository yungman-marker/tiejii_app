import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// 桌面端「个人中心」主区容器（master-detail 范式）。
///
/// 布局：
/// ```
/// ┌─────────────────────────────────────────────────────┐
/// │  💬 对话  ›  当前节名  (面包屑，点击「对话」回主页)  │
/// ├──────────────┬──────────────────────────────────────┤
/// │  账户        │                                       │
/// │   · 账号管理 │                                       │
/// │   · 数据管理 │        右侧 [child] (路由页面)        │
/// │  应用        │                                       │
/// │   · 语言     │        P1: 仍是原全屏 Scaffold        │
/// │   · 外观主题 │        P2: 改为无 Scaffold 的内容组件  │
/// │  关于        │                                       │
/// │  隐私与反馈  │                                       │
/// │  ──────────  │                                       │
/// │  ⎋ 退出登录  │                                       │
/// └──────────────┴──────────────────────────────────────┘
///      240px                  flex:1
/// ```
///
/// [child] 是 GoRouter 当前匹配的页面（MeScreen / SettingsScreen / 等）。
/// 当前活动菜单项由 [GoRouterState.matchedLocation] 推导；点击菜单项走
/// [GoRouter.go]（**不是** push，避免在 shell 栈里堆积）。
class MeShellDesktop extends ConsumerWidget {
  const MeShellDesktop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final section = _sectionFromPath(loc);
    // 顶部面包屑已移除（用户反馈视觉冗余），[label] 已不再消费；
    // [_labelFromPath] 工具方法保留，后续若加"右侧页面头部标题"可复用。

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 240,
            child: _Sidebar(activeSection: section),
          ),
          Container(
              width: 1,
              color: Theme.of(context).dividerColor),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  String _sectionFromPath(String path) {
    if (path.startsWith('/me/settings')) return 'settings';
    if (path.startsWith('/me/data')) return 'data';
    if (path.startsWith('/me/privacy')) return 'privacy';
    if (path.startsWith('/me/feedback')) return 'feedback';
    if (path.startsWith('/me/memory')) return 'memory';
    if (path.startsWith('/me/appearance')) return 'appearance';
    if (path.startsWith('/me/language')) return 'language';
    return '';
  }
}

/// 面包屑：对话 / 当前节名。点击「对话」回主页。
/// 面包屑：对话 / 当前节名。点击「对话」回主页。
/// （P1 旧版 _Breadcrumb 已删除，注释留作历史参考）

/// 桌面端 240px 侧边菜单。
class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.activeSection});

  final String activeSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionHeader('账户'),
          _item(
            context,
            icon: Icons.person_outline,
            label: '账号管理',
            section: 'settings',
            onTap: () => context.go('/me/settings'),
          ),
          _item(
            context,
            icon: Icons.storage_outlined,
            label: '数据管理',
            section: 'data',
            onTap: () => context.go('/me/data'),
          ),
          _sectionHeader('应用'),
          _item(
            context,
            icon: Icons.palette_outlined,
            label: '外观主题',
            section: 'appearance',
            onTap: () => context.go('/me/appearance'),
          ),
          _item(
            context,
            icon: Icons.translate_outlined,
            label: '语言',
            section: 'language',
            onTap: () => context.go('/me/language'),
          ),
          _sectionHeader('关于'),
          _item(
            context,
            icon: Icons.system_update_alt_outlined,
            label: '检查更新',
            section: 'update',
            trailing: '1.0.0',
            onTap: () => _tip(context, '已是最新版本 1.0.0'),
          ),
          _item(
            context,
            icon: Icons.description_outlined,
            label: '服务协议',
            section: 'tos',
            onTap: () => _tip(context, '服务协议：待后端提供'),
          ),
          _sectionHeader('隐私与反馈'),
          _item(
            context,
            icon: Icons.shield_outlined,
            label: '隐私与权限',
            section: 'privacy',
            onTap: () => context.go('/me/privacy'),
          ),
          _item(
            context,
            icon: Icons.feedback_outlined,
            label: '意见反馈',
            section: 'feedback',
            onTap: () => context.go('/me/feedback'),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 0.5,
            color: AppColors.divider,
          ),
          _item(
            context,
            icon: Icons.logout,
            label: '退出登录',
            section: 'logout',
            isDanger: true,
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String section,
    bool isDanger = false,
    String? trailing,
    required VoidCallback onTap,
  }) {
    final active = activeSection == section;
    final scheme = Theme.of(context).colorScheme;
    final fg = isDanger
        ? AppColors.danger
        : (active ? scheme.primary : scheme.onSurface);
    final iconClr = isDanger
        ? AppColors.danger
        : (active ? scheme.primary : scheme.onSurfaceVariant);
    final trailingStyle = TextStyle(
      fontSize: 11,
      color: scheme.onSurfaceVariant,
    );
    return Material(
      color: active ? AppColors.primarySoft : Colors.transparent,
      child: Stack(
        children: [
          // active 左侧 3px 蓝色 indicator（Notion 风格），未激活时不占位
          if (active)
            Positioned(
              left: 0,
              top: 6,
              bottom: 6,
              width: 3,
              child: Container(color: AppColors.primary),
            ),
          InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: iconClr),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: fg,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Text(
                      trailing,
                      style: trailingStyle,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Builder(builder: (ctx) {
          return Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          );
        }),
      );

  void _tip(BuildContext ctx, String message) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));

  void _confirmLogout(BuildContext ctx, WidgetRef ref) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出当前账号？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authControllerProvider.notifier).logout();
              // isLoggedIn 变 false，GoRouter redirect 会自动跳到 /login
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
