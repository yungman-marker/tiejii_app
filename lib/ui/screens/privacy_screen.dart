import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';

/// 隐私与权限（/me/privacy）。
/// 顶部：长期记忆设置入口（点击进入记忆设置页）
/// 中部：系统权限列表（麦克风 / 相机 / 相册 / 位置）
/// 底部：前往系统权限管理（系统级入口，本端仅占位提示）
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, this.onMemoryTap});

  /// 覆盖「长期记忆设置」入口的点击行为。
  ///
  /// 默认（独立使用时）= `() => context.push('/me/memory')`。
  ///
  /// 当 [PrivacyScreen] 被设置弹层（`SettingsDialog`）**嵌入**右侧时，
  /// 弹层挂在 root Navigator 上、`context.push` 会被弹层盖住、视觉上
  /// 看不到新页面（go_router 已切路由但弹层未关）。此时弹层会传入
  /// 「先关弹层再 push 路由」的回调。
  final VoidCallback? onMemoryTap;

  /// 模拟系统权限状态（与设计稿一致）。如接入原生权限 SDK 替换此处即可。
  static const Map<String, _Perm> _permissions = {
    '麦克风': _Perm(icon: Icons.mic_none_outlined, status: '未请求'),
    '相机': _Perm(icon: Icons.camera_alt_outlined, status: '已开启'),
    '相册': _Perm(icon: Icons.photo_outlined, status: '已开启'),
    '位置': _Perm(icon: Icons.location_on_outlined, status: '已开启'),
  };

  @override
  Widget build(BuildContext context) {
    final isWide = isDesktop(context);
    return Scaffold(
      appBar: AppBar(
        leading: isWide
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => context.pop(),
              ),
        title: const Text('隐私与权限'),
        centerTitle: true,
      ),
      body: SafeArea(bottom: false, child: _buildBody(context)),
    );
  }

  /// 主体内容。
  Widget _buildBody(BuildContext context) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                _MemoryEntryCard(
                  onTap: onMemoryTap ?? () => context.push('/me/memory'),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
                  child: Text(
                    '为提供更好的体验，铁骥大模型将向你请求以下系统权限',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5),
                  ),
                ),
                const _PermissionsCard(permissions: _permissions),
                const SizedBox(height: 24),
                Center(
                  child: _SystemPermissionButton(
                    onTap: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text(
                          '系统权限管理：由手机系统提供',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary),
                        ),
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        behavior: SnackBarBehavior.floating,
                      )),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _Perm {
  const _Perm({required this.icon, required this.status});
  final IconData icon;
  final String status;
}

class _MemoryEntryCard extends StatelessWidget {
  const _MemoryEntryCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(Icons.settings_outlined,
                    size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('长期记忆设置',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text('开启后 AI 会记住你的岗位与偏好',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                            height: 1.4)),
                  ],
                ),
              ),
              Text('已开启',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.permissions});
  final Map<String, _Perm> permissions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = permissions.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final name = entries[i].key;
          final p = entries[i].value;
          final isLast = i == entries.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                          color: scheme.outlineVariant, width: 0.5)),
            ),
            child: Row(
              children: [
                Icon(p.icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                ),
                Text(p.status,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SystemPermissionButton extends StatelessWidget {
  const _SystemPermissionButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.outbond_outlined,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 4),
              Text('前往系统权限管理',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
