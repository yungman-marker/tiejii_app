import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';

/// 个人中心菜单（分组：账户 / 应用 / 关于 / 隐私与反馈），被全屏页 [MeScreen] 复用。
///
/// 多数菜单属于「调用手机系统功能」，**不对接 Web 端接口**：
///   语言 / 外观 / 检查更新 / 服务协议 / 数据管理 → 仅本地展示或轻提示，不发网络请求。
/// 真正走接口的项：账号管理(/me/settings)、隐私与权限(/me/privacy)、
/// 意见反馈(/me/feedback)、退出登录(auth)。
Widget buildMeMenu(BuildContext context, WidgetRef ref) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
    children: [
      // ── 账户 ──────────────────────────────────────────
      _sectionHeader('账户'),
      _group([
        _row(Icons.person_outline, '账号管理',
            onTap: () => context.push('/me/settings')),
        _row(Icons.storage_outlined, '数据管理',
            onTap: () => context.push('/me/data')),
      ]),

      // ── 应用 ──────────────────────────────────────────
      _sectionHeader('应用'),
      _group([
        _row(Icons.translate_outlined, '语言',
            trailing: _localeLabel(ref.watch(localeProvider)),
            onTap: () => context.push('/me/language')),
        _row(Icons.palette_outlined, '外观',
            trailing: _themeModeLabel(ref.watch(themeModeProvider)),
            onTap: () => context.push('/me/appearance')),
      ]),

      // ── 关于 ──────────────────────────────────────────
      _sectionHeader('关于'),
      _group([
        _row(Icons.system_update_alt_outlined, '检查更新',
            trailing: '1.0.0',
            onTap: () => _tip(context, '已是最新版本 1.0.0')),
        _row(Icons.description_outlined, '服务协议',
            onTap: () => _tip(context, '服务协议：由手机端打开')),
      ]),

      // ── 隐私与反馈（合：隐私与权限 + 意见反馈）────────
      _sectionHeader('隐私与反馈'),
      _group([
        _row(Icons.shield_outlined, '隐私与权限',
            onTap: () => context.push('/me/privacy')),
        _row(Icons.feedback_outlined, '意见反馈',
            onTap: () => context.push('/me/feedback')),
      ]),

      // ── 退出登录（红色独立按钮）─────────────────────
      const SizedBox(height: 10),
      _group([
        _row(Icons.logout, '退出登录',
            labelColor: AppColors.danger,
            iconColor: AppColors.danger,
            onTap: () => _confirmLogout(context, ref)),
      ]),
    ],
  );
}

/// 个人中心（全屏页，路由 /me）。左上角返回按钮，从右侧往左滑入（千问风）。
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 桌面端（master-detail 容器）：没有"上一级"概念，← 去掉。
    // 导航由中间的 240px 菜单 + 顶部面包屑统一负责。
    // 移动/窄屏：保留 ← 走 Navigator.pop，回到上一页（通常是抽屉 push 之前的位置）。
    final isWide = isDesktop(context);
    return Scaffold(
      appBar: AppBar(
        leading: isWide
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => context.pop(),
              ),
        title: const Text('个人中心'),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: buildMeMenu(context, ref),
      ),
    );
  }
}

/// 圆角白卡容器：函数式而非 widget 类，避免父级 children 触发
/// `prefer_const_constructors` 提示（容器即 const 友好 + boxShadow 装饰）。
Widget _group(List<Widget> rows) => Builder(builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline),
          boxShadow: [
            if (Theme.of(ctx).brightness == Brightness.light)
              const BoxShadow(
                color: Color(0x11000000),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      );
    });

/// 单行菜单：图标 + 菜单名 +（可选右侧文字）+ 箭头；
/// 末行无下边线；菜单名 / 图标可独立配色（用于退出登录红色）。
Widget _row(
  IconData icon,
  String label, {
  String? trailing,
  Color? iconColor,
  Color? labelColor,
  VoidCallback? onTap,
}) {
  return Builder(builder: (ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    final fg = labelColor ?? scheme.onSurface;
    final iconClr = iconColor ?? scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: iconClr),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    trailing,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right,
                size: 17,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  });
}

/// 分组小标题：浅灰小字。
Widget _sectionHeader(String text) => Builder(builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
      );
    });

void _tip(BuildContext ctx, String message) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));

/// 语言菜单右侧文字：跟随系统 / 简体中文 / English。
String _localeLabel(Locale? locale) {
  if (locale == null) return '跟随系统';
  if (locale.languageCode == 'zh') return '简体中文';
  if (locale.languageCode == 'en') return 'English';
  return '跟随系统';
}

/// 外观菜单右侧文字：系统 / 浅色 / 深色。
String _themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.light => '浅色',
      ThemeMode.dark => '深色',
      ThemeMode.system => '系统',
    };

/// 触发退出登录的二次确认框（AlertDialog）。
///
/// ## 三个关键修复
///
/// 1. **`builder` 用 dialogBuilder 的 [dialogCtx] 而非闭包外的 `ctx`**：
///    之前 `Navigator.pop(ctx)` 中 `ctx` 是 me_screen 的 BuildContext——
///    close 链路正确但**容易误关掉 me 路由本身**（特别是登出后 ctx 仍可能引用
///    已经 replaced 的元素链）。换成 dialogBuilder 的 ctx 之后，pop 永远只关闭
///    当前对话框，不再涉及外层路由。
///
/// 2. **「取消」按钮只为 pop dialog，不做其它动作**。之前如果 onPressed
///    错误地闭上了 me 路由，整个 me_screen 会被销毁；下一次按就找不到 onPressed
///    绑定的元素了，于是出现「点击取消、退出都没有任何反应」的卡死感。
///
/// 3. **「退出」按确认顺序**：先 pop dialog → 再 logout() → 最后 `await` 让
///    router redirect 走完。三步**串行**，避免在 dialog 还没关闭时竞争路由。
void _confirmLogout(BuildContext ctx, WidgetRef ref) {
  showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('退出登录'),
      content: const Text('确定退出当前账号？'),
      actions: [
        TextButton(
          // 「取消」：只关闭 dialog 即可，不做任何额外动作。
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () async {
            // ① 先关 dialog；保证下一帧 dialog 就消失，避免与 router 重定向抢焦点。
            Navigator.of(dialogCtx).pop();
            // ② 触发 auth 状态变更（清 token / 清本地身份），isLoggedIn 变 false。
            await ref.read(authControllerProvider.notifier).logout();
            // ③ GoRouter redirect 会自动把用户送到 /login，这里不主动 pop()/go()，
            //    避免与 redirect 重叠导致 me 路由被多 pop 一次。
            //    （redirect 规则见 app_router.dart：!isLoggedIn && !atLogin → /login）
          },
          child: const Text('退出'),
        ),
      ],
    ),
  );
}
