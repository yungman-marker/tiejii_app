import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      if (!isLoggedIn && !atLogin) return '/login';
      if (isLoggedIn && atLogin) return '/chat';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // 已登录主框架（3 Tab）
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
        ],
      ),
      // 抽屉 push 出来的页面（覆盖底栏），千问风：从右往左滑入。
      GoRoute(
        path: '/me',
        pageBuilder: (context, state) => _slidePage(const MeScreen()),
        routes: [
          GoRoute(
            path: 'settings',
            pageBuilder: (context, state) => _slidePage(const SettingsScreen()),
          ),
          GoRoute(
            path: 'data',
            pageBuilder: (context, state) => _slidePage(const DataManagementScreen()),
          ),
          GoRoute(
            path: 'privacy',
            pageBuilder: (context, state) => _slidePage(const PrivacyScreen()),
          ),
          GoRoute(
            path: 'memory',
            pageBuilder: (context, state) => _slidePage(const MemoryScreen()),
          ),
          GoRoute(
            path: 'feedback',
            pageBuilder: (context, state) => _slidePage(const FeedbackScreen()),
          ),
        ],
      ),
      // 智能体详情
      GoRoute(
        path: '/agents/:id',
        builder: (context, state) =>
            AgentDetailScreen(agentId: state.pathParameters['id']!),
      ),
      // 知识库搜索
      GoRoute(
        path: '/knowledge/search',
        builder: (context, state) => const KbSearchScreen(),
      ),
      // 搜索结果 · AI 总结
      GoRoute(
        path: '/knowledge/results',
        builder: (context, state) {
          final q = state.uri.queryParameters['q'] ?? '';
          return KbResultsScreen(query: q);
        },
      ),
      // 目录文件列表（点进某个目录后查看其下文件）
      GoRoute(
        path: '/knowledge/dir',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return KnowledgeDirScreen(
            dirId: q['dirId'] ?? '',
            dirName: q['name'] ?? '目录',
            type: q['type'] ?? '1',
          );
        },
      ),
      // 文件预览（在 APP 内打开，不跳外部浏览器）
      GoRoute(
        path: '/file/preview',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return FilePreviewScreen(
            url: q['url'] ?? '',
            name: q['name'] ?? '',
            ext: q['ext'] ?? '',
          );
        },
      ),
    ],
  );
});

/// 统一「从右往左滑入」转场（千问风），用于个人中心及其子菜单全屏页。
CustomTransitionPage<dynamic> _slidePage(Widget child) => CustomTransitionPage<dynamic>(
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
