import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// 账号管理（/me/settings），样式参考「DeepSeek App · Account」：
///
///   账号绑定
///   ┌─────────────────────────┐
///   │ 📱 手机号      未绑定 › │
///   │ ✉️ 邮箱        未绑定 › │
///   │ 💬 微信        未绑定 › │
///   └─────────────────────────┘
///   登录与安全
///   ┌─────────────────────────┐
///   │ 📲 登录设备管理  1台 › │
///   │ 🔒 修改密码          › │
///   └─────────────────────────┘
///   危险操作
///   ┌─────────────────────────┐
///   │ ⚠️ 注销账号（红）     › │
///   └─────────────────────────┘
///
/// 顶部不再保留「账户概览」卡——按用户要求前后都不要。
///
/// 后端 [UserProfile] 当前只提供 userName/nickName/avatar/enterprise/roles，
/// **没有**手机号 / 邮箱 / 第三方绑定等字段与换绑接口，因此这些行以 UI 呈现
/// （trailing 显示"未绑定"），点击给出"由手机端 / 后端提供"提示，不伪造请求。
/// 「注销账号」确认后走 logout()——后端暂无独立注销端点，等价于退出登录并清本地身份。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 仅订阅 auth 状态（用于注销时调 logout()），本页面不展示头像/昵称等资料。
    ref.watch(authControllerProvider);
    final isWide = isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        leading: isWide
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => context.pop(),
              ),
        title: const Text('账号管理'),
        centerTitle: true,
      ),
      body: SafeArea(bottom: false, child: _buildList(context, ref)),
    );
  }

  /// 列表主体。
  Widget _buildList(BuildContext context, WidgetRef ref) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          // ── 账号绑定 ────────────────────────────────────
          _sectionHeader('账号绑定'),
          _group([
            _row(Icons.phone_iphone_outlined, '手机号',
                trailing: '未绑定',
                onTap: () => _tip(context, '换绑手机号：由手机端 / 后端提供')),
            _row(Icons.email_outlined, '邮箱',
                trailing: '未绑定',
                onTap: () => _tip(context, '绑定邮箱：由手机端 / 后端提供')),
            _row(Icons.chat_outlined, '微信',
                trailing: '未绑定',
                onTap: () => _tip(context, '微信绑定：由手机端 / 后端提供')),
          ]),

          // ── 登录与安全 ──────────────────────────────────
          _sectionHeader('登录与安全'),
          _group([
            _row(Icons.devices_outlined, '登录设备管理',
                trailing: '1 台设备',
                onTap: () => _tip(context, '登录设备管理：由手机端提供')),
            _row(Icons.lock_outline, '修改密码',
                onTap: () => _tip(context, '修改密码：请前往登录页「忘记密码」')),
          ]),

          // ── 危险操作 ────────────────────────────────────
          _sectionHeader('危险操作'),
          _group([
            _row(Icons.delete_forever_outlined, '注销账号',
                labelColor: AppColors.danger,
                iconColor: AppColors.danger,
                onTap: () => _confirmDelete(context, ref)),
          ]),

          const SizedBox(height: 20),
        ],
      );

  void _tip(BuildContext ctx, String message) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));

  void _confirmDelete(BuildContext ctx, WidgetRef ref) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text(
          '注销后，所有对话记录、记忆数据将被永久删除且不可恢复。'
          '确定继续？',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              // 后端暂无独立注销端点：清掉本地 JWT 等价退出登录并清本地身份。
              // 接真实注销接口时，此处改为调用后端 deleteAccount 再 logout。
              ref.read(authControllerProvider.notifier).logout();
            },
            child: const Text('注销'),
          ),
        ],
      ),
    );
  }

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

  Widget _group(List<Widget> rows) => Builder(builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline),
            boxShadow: [
              BoxShadow(
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? Colors.transparent
                    : const Color(0x11000000),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        );
      });

  Widget _row(
    IconData icon,
    String label, {
    String? trailing,
    Color? labelColor,
    Color? iconColor,
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
}
