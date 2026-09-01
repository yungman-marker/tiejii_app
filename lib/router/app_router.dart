import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/responsive.dart';
import '../providers/auth_provider.dart';
import '../ui/screens/agent_center_screen.dart';
import '../ui/screens/agent_detail_screen.dart';
import '../ui/screens/chat_screen.dart';
import '../ui/screens/data_management_screen.dart';
import '../ui/screens/feedback_screen.dart';
import '../ui/screens/kb_results_screen.dart';
import '../ui/screens/kb_search_screen.dart';
import '../ui/screens/knowledge_screen.dart';
import '../ui/screens/knowledge_dir_screen.dart';
import '../ui/screens/file_preview_screen.dart';
import '../ui/screens/appearance_screen.dart';
import '../ui/screens/language_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/main_shell.dart';
import '../ui/screens/memory_screen.dart';
import '../ui/screens/me_screen.dart';
import '../ui/screens/privacy_screen.dart';
import '../ui/screens/settings_screen.dart';


/// 应用路由
///
/// 结构：
///   /login                              ← 登录（账号密码 / 手机号占位 / 企微 / 铁建通）
///   ShellRoute (已登录)
///     /chat         (tab 0, 对话)       ← 含左滑抽屉
///     /agents       (tab 1, 智能体)
///     /knowledge    (tab 2, 知识库)
///   /me                                ← 从抽屉 push，覆盖底栏
///   /me/settings
///   /me/privacy
///   /me/memory
///   /me/feedback
///   /agents/:id                        ← 智能体详情
///   /knowledge/search                  ← 智能搜索
///   /knowledge/results                 ← 搜索结果 · AI 总结
final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn =
      ref.watch(authControllerProvider.select((s) => s.isLoggedIn));

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final atLogin = loc == '/login';

      // 桌面端首次进入 /me：直接 anchor 到第一个子菜单 /me/settings（账号管理）
      // 避免 master-detail 容器里同时展示原 MeScreen 的 5 段菜单，与中间
      // 240px 的 _Sidebar 导航菜单视觉重叠。窄屏（移动端）保持原 /me 全屏
      // push 行为不变。
      if (isLoggedIn && loc == '/me' && isDesktop(context)) {
        return '/me/settings';
      }

      if (!isLoggedIn && !atLogin) return '/login';
      if (isLoggedIn && atLogin) return '/chat';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // 已登录主框架（3 Tab + /me 区域）。
      // /me 放在 ShellRoute 内，让桌面端 MainShell 能根据 matchedLocation 把它
      // 包装成 master-detail 容器（MeShellDesktop）；移动端 MainShell 只是
      // Scaffold(body: child)，所以 /me 仍然呈现为「全屏 push」效果，
      // 但 pageBuilder 里继续用 _slidePage 保留从右滑入转场。
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/chat',
            pageBuilder: (context, state) => const NoTransitionPage(child: ChatScreen()),
          ),
          GoRoute(
            path: '/agents',
            pageBuilder: (context, state) => const NoTransitionPage(child: AgentCenterScreen()),
          ),
          GoRoute(
            path: '/knowledge',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: KnowledgeScreen()),
          ),
          // /me 及其子页：全部拍平到 ShellRoute 同级（不要用 nested routes +
          // pageBuilder，因为 go_router 14.x 在 ShellRoute + 嵌套 pageBuilder
          // 的组合下，会出现"父 pageBuilder 锁住 child、子路由生效但
          // shell.child 仍是父 widget"的 bug）。
          // 每个 /me/* 都是独立 pageBuilder，路由切换时 shell.child 必然是
          // 对应的子 widget。
          GoRoute(
            path: '/me',
            pageBuilder: (context, state) => isDesktop(context)
                ? const NoTransitionPage(child: MeScreen())
                : _slidePage(const MeScreen()),
          ),
          GoRoute(
            path: '/me/settings',
            pageBuilder: (context, state) => isDesktop(context)
                ? const NoTransitionPage(child: SettingsScreen())
                : _slidePage(const SettingsScreen()),
          ),
          GoRoute(
            path: '/me/data',
            pageBuilder: (context, state) => isDesktop(context)
                ? const NoTransitionPage(child: DataManagementScreen())
                : _slidePage(const DataManagementScreen()),
          ),
          GoRoute(
            path: '/me/privacy',
            pageBuilder: (context, state) => isDesktop(context)
                ? const NoTransitionPage(child: PrivacyScreen())
                : _slidePage(const PrivacyScreen()),
          ),
          GoRoute(
            path: '/me/memory',
            pageBuilder: (context, state) => isDesktop(context)
                ? const NoTransitionPage(child: MemoryScreen())
                : _slidePage(const MemoryScreen()),
          ),
          GoRoute(
            path: '/me/appearance',
            pageBuilder: (context, state) => isDesktop(context)
                ? const NoTransitionPage(child: AppearanceScreen())
                : _slidePage(const AppearanceScreen()),
          ),
          GoRoute(
            path: '/me/language',
            pageBuilder: (context, state) => isDesktop(context)
                ? const NoTransitionPage(child: LanguageScreen())
                : _slidePage(const LanguageScreen()),
          ),
          GoRoute(
            path: '/me/feedback',
            pageBuilder: (context, state) => isDesktop(context)
                ? const NoTransitionPage(child: FeedbackScreen())
                : _slidePage(const FeedbackScreen()),
          ),
        ],
      ),
      // 智能体详情
      GoRoute(
        path: '/agents/:id',
        pageBuilder: (context, state) {
          final child = AgentDetailScreen(agentId: state.pathParameters['id']!);
          return isDesktop(context)
              ? MaterialPage<dynamic>(child: child)
              : CupertinoPage<dynamic>(child: child);
        },
      ),
      // 知识库搜索
      GoRoute(
        path: '/knowledge/search',
        pageBuilder: (context, state) => isDesktop(context)
            ? const MaterialPage<dynamic>(child: KbSearchScreen())
            : const CupertinoPage<dynamic>(child: KbSearchScreen()),
      ),
      // 搜索结果 · AI 总结
      GoRoute(
        path: '/knowledge/results',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters['q'] ?? '';
          final child = KbResultsScreen(query: q);
          return isDesktop(context)
              ? MaterialPage<dynamic>(child: child)
              : CupertinoPage<dynamic>(child: child);
        },
      ),
      // 目录文件列表（点进某个目录后查看其下文件）
      GoRoute(
        path: '/knowledge/dir',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          final child = KnowledgeDirScreen(
            dirId: q['dirId'] ?? '',
            dirName: q['name'] ?? '目录',
            type: q['type'] ?? '1',
          );
          return isDesktop(context)
              ? MaterialPage<dynamic>(child: child)
              : CupertinoPage<dynamic>(child: child);
        },
      ),
      // 文件预览（在 APP 内打开，不跳外部浏览器）
      GoRoute(
        path: '/file/preview',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          final child = FilePreviewScreen(
            url: q['url'] ?? '',
            name: q['name'] ?? '',
            ext: q['ext'] ?? '',
          );
          return isDesktop(context)
              ? MaterialPage<dynamic>(child: child)
              : CupertinoPage<dynamic>(child: child);
        },
      ),
    ],
  );
});

/// 统一「从右往左滑入」转场（千问风），用于个人中心及其子菜单全屏页。
///
/// 使用 [CupertinoPage]：原生 iOS「从右滑入」动画 + 自带**左边缘滑动返回手势**
/// （CustomTransitionPage 不带手势，所以之前手机端无法左滑回退）。
/// 仅移动端调用（桌面端 /me/* 走 NoTransitionPage，不进此函数）。
Page<dynamic> _slidePage(Widget child) => CupertinoPage<dynamic>(child: child);
