import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';

/// 隐私与权限（/me/privacy）。
/// 顶部：长期记忆设置入口（点击进入记忆设置页）
/// 中部：系统权限列表（麦克风 / 相机 / 相册）——**真实读系统授权状态、点行可请求或跳设置**
/// 底部：前往系统权限管理（跳转到手机系统的 App 设置页）
///
/// 实现说明：
/// - 移动端（android / iOS）用 [permission_handler] 读真实状态；点行：未授权→`request()`
///   弹系统框，授权后再弹窗；已拒绝→iOS 不会二次弹窗，直接 `openAppSettings()` 跳系统设置。
/// - 桌面端（Windows 等 permission_handler 不支持的平台）不调用原生 API，状态显示
///   "由系统提供"，点行仅提示，避免 MissingPluginException / 崩溃。
class PrivacyScreen extends StatefulWidget {
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

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

/// 权限行：图标 + 对应系统权限。
class _Row {
  const _Row(this.icon, this.permission);
  final IconData icon;
  final Permission permission;
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  /// 仅保留 App 真正使用到的权限：麦克风 / 相机 / 相册。
  /// 「位置」App 未使用，按隐私设计不向用户索取，故不列出。
  static const Map<String, _Row> _rows = {
    '麦克风': _Row(Icons.mic_none_outlined, Permission.microphone),
    '相机': _Row(Icons.camera_alt_outlined, Permission.camera),
    '相册': _Row(Icons.photo_outlined, Permission.photos),
  };

  final Map<String, PermissionStatus> _statuses = {};
  bool _isMobile = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (_isMobile) {
      _loadStatuses();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadStatuses() async {
    final m = <String, PermissionStatus>{};
    for (final e in _rows.entries) {
      try {
        m[e.key] = await e.value.permission.status;
      } catch (_) {
        // 个别权限在特殊机型上读取异常，按「未开启」处理，不影响其它行。
        m[e.key] = PermissionStatus.denied;
      }
    }
    if (mounted) setState(() {
      _statuses.addAll(m);
      _loading = false;
    });
  }

  Future<void> _onRowTap(String name) async {
    if (!_isMobile) {
      _tip('请在手机端管理权限');
      return;
    }
    final perm = _rows[name]!.permission;
    final current = _statuses[name] ?? await perm.status;
    if (current == PermissionStatus.granted) {
      _tip('$name 已授权');
      return;
    }
    // 未授权先尝试弹系统请求框；若用户拒绝，iOS 不会二次弹窗，跳系统设置授权。
    final result = await perm.request();
    if (mounted) setState(() => _statuses[name] = result);
    if (result != PermissionStatus.granted) {
      await openAppSettings();
    }
  }

  Future<void> _onSystemSettingsTap() async {
    if (!_isMobile) {
      _tip('请在手机端管理权限');
      return;
    }
    await openAppSettings();
  }

  void _tip(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  PermissionStatus? _statusOf(String name) => _statuses[name];

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
                  onTap: widget.onMemoryTap ?? () => context.push('/me/memory'),
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
                _PermissionsCard(
                  rows: _rows,
                  isMobile: _isMobile,
                  loading: _loading,
                  statusOf: _statusOf,
                  onTap: _onRowTap,
                ),
                const SizedBox(height: 24),
                Center(
                  child: _SystemPermissionButton(onTap: _onSystemSettingsTap),
                ),
              ],
            ),
          ),
        ],
      );
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
  const _PermissionsCard({
    required this.rows,
    required this.isMobile,
    required this.loading,
    required this.statusOf,
    required this.onTap,
  });
  final Map<String, _Row> rows;
  final bool isMobile;
  final bool loading;
  final PermissionStatus? Function(String name) statusOf;
  final void Function(String name) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = rows.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final name = entries[i].key;
          final row = entries[i].value;
          final isLast = i == entries.length - 1;

          final st = statusOf(name);
          final granted = isMobile && st == PermissionStatus.granted;
          final statusText = !isMobile
              ? '由系统提供'
              : loading
                  ? '读取中'
                  : granted
                      ? '已开启'
                      : '未开启';
          final statusColor = !isMobile || !granted
              ? scheme.onSurfaceVariant
              : Colors.green;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTap(name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                              color: scheme.outlineVariant, width: 0.5),
                        ),
                ),
                child: Row(
                  children: [
                    Icon(row.icon, size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface)),
                    ),
                    Text(statusText,
                        style: TextStyle(fontSize: 12, color: statusColor)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 16, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
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
