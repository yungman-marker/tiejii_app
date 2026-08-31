import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../screens/appearance_screen.dart';
import '../screens/data_management_screen.dart';
import '../screens/feedback_screen.dart';
import '../screens/memory_screen.dart';
import '../screens/privacy_screen.dart';
import '../screens/settings_screen.dart';

/// 设置弹层（仿 WorkBuddy 桌面端"设置"对话框）：
///
///   ┌─────────────────────────────────────────────┐
///   │ 设置      │      <内嵌屏幕的内容>      (×)   │
///   │ 账号管理  │                                │
///   │ 数据管理  │                                │
///   │ ...       │                                │
///   │ 退出登录  │                                │
///   └─────────────────────────────────────────────┘
///
/// - 左 220px 是分类侧栏（点击切换右侧内容），8 项分类与项目内
///   `_Sidebar`（原 /me 240px 侧栏）**逐项对齐**：
///   账号管理 / 数据管理 / 外观主题 / 检查更新 / 服务协议 /
///   隐私与权限 / 意见反馈 / 退出登录。
/// - 右剩余宽度装「对应分类的页面」：
///   - 已实现的 5 项（账号管理 / 数据管理 / 外观主题 / 隐私与权限 /
///     意见反馈）直接复用现有屏幕；
///   - 2 项（检查更新 / 服务协议）给出「该分类正在开发中」占位；
///   - 1 项（退出登录）是动作项，点击弹二次确认 + 调 auth.logout，
///     不进入选中态（不显示右侧内容）。
/// - 顶部右上角的 (×) 关闭按钮负责关掉整个弹层。
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  /// 弹出整层。
  static Future<void> show(BuildContext context) =>
      showGeneralDialog<void>(
        context: context,
        barrierLabel: '设置',
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const SettingsDialog(),
        transitionBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        ),
      );

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

/// 8 个分类——与项目内 `_Sidebar`（原 /me 桌面端 240px 侧栏）8 项菜单
/// **逐项对齐**，不照搬 WorkBuddy 截图上的 11 项，避免「截图菜单 vs
/// 项目菜单」名字错配（之前用 11 项时，"关于我们"里塞的却是"意见反馈"
/// 屏、"安全中心"对应项目里的"隐私与权限"，驴头不对马嘴）。
///
/// - 退出登录是**动作项**而非**内容项**：[isDanger]=true，点击不进
///   [_select]，直接弹二次确认 + 调 [AuthController.logout]。
/// - 其余 7 项点中后，右侧 [_buildContent] 展示对应 Screen / 占位。
enum SettingsCategory {
  accountMgmt('账号管理', Icons.person_outline),
  dataMgmt('数据管理', Icons.storage_outlined),
  appearance('外观主题', Icons.palette_outlined),
  checkUpdate('检查更新', Icons.system_update_alt_outlined),
  tos('服务协议', Icons.description_outlined),
  privacy('隐私与权限', Icons.shield_outlined),
  feedback('意见反馈', Icons.feedback_outlined),
  logout('退出登录', Icons.logout, isDanger: true),
  ;

  const SettingsCategory(this.title, this.icon, {this.isDanger = false});
  final String title;
  final IconData icon;

  /// 「退出登录」专用：颜色变红 + 跳过选中态 + 点击走确认 + 注销。
  final bool isDanger;
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  // 默认 anchor 到「账号管理」——和原 _Sidebar 在 /me 首次进入时由
  // router redirect 跳到 '/me/settings' 的默认行为保持一致。
  SettingsCategory _selected = SettingsCategory.accountMgmt;

  /// 二级页（从某个分类页点进去的子页面，目前只有「记忆设置」一个）。
  ///
  /// null = 显示 [_selected] 对应的分类主内容。
  ///
  /// 这些子页**在弹层内原地展开**，不走 go_router —— 弹层挂在 root
  /// Navigator 上，从弹层里 push 路由会让新页面显示在弹窗背后，
  /// 且 `context.pop()` 会把整个弹层一起关掉。
  Widget? _subPage;

  void _select(SettingsCategory c) => setState(() {
        _selected = c;
        _subPage = null; // 切分类时收起二级页
      });

  /// 在弹层内展开二级页。
  void _openSubPage(Widget page) => setState(() => _subPage = page);

  /// 从二级页退回上层分类页。
  void _closeSubPage() => setState(() => _subPage = null);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    // 弹层尺寸下限（不能无限缩小，否则右侧内容展示不全）+ 上限跟随窗口
    // 留出 48px 边距（避免弹层比窗口还大、溢出屏幕）。
    final maxW = (mq.size.width - 48).clamp(720.0, 980.0);
    final maxH = (mq.size.height - 48).clamp(500.0, 660.0);

    // 与 WorkBuddy 桌面端一致：桌面端窗口足够大时呈现固定比例的弹层；
    // min/max 收口，用户把窗口拖小也只会缩到 720×500 下限，内容始终完整。
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 720,
          maxWidth: maxW,
          minHeight: 500,
          maxHeight: maxH,
        ),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          elevation: 12,
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 220,
                child: _buildSidebar(scheme),
              ),
              VerticalDivider(width: 1, color: scheme.outlineVariant),
              Expanded(child: _buildContent(scheme)),
            ],
          ),
        ),
      ),
    );
  }

  /// 左侧分类列表（点击切换右侧内容）；顶部含「设置」标题和关闭 (×)，与 WorkBuddy
/// 桌面端"标题+关闭按钮"同侧对齐，避免与右侧内嵌屏幕的 AppBar 重叠。
  Widget _buildSidebar(ColorScheme scheme) {
    return Container(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
            child: Row(
              children: [
                Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
                  tooltip: '关闭',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                for (final c in SettingsCategory.values)
                  if (c.isDanger) ...[
                    // 退出登录前留一道分隔线，与原 _Sidebar 视觉一致
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, thickness: 1),
                    ),
                    _buildLogoutTile(scheme, c),
                  ] else
                    _buildCategoryTile(scheme, c, selected: c == _selected),
              ],
            ),
          ),
          // 底部品牌签名（WorkBuddy 同款有底部署名区域）
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 18),
            child: Text(
              'tiejii  v0.1.0',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    ColorScheme scheme,
    SettingsCategory c, {
    required bool selected,
  }) {
    // 选中态：浅蓝（primary 含透明）底；非选中：透明底 + onSurfaceVariant 灰。
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.10)
        : Colors.transparent;
    final fg = selected ? scheme.primary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _select(c),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(c.icon, size: 18, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.title,
                    style: TextStyle(
                      fontSize: 14,
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 「退出登录」专用 tile：danger 红、点击不进入 _select 选中态、
  /// 直接走 [_confirmAndLogout] 二次确认 + 调 auth.logout。
  Widget _buildLogoutTile(ColorScheme scheme, SettingsCategory c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _confirmAndLogout,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(c.icon, size: 18, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.title,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 二次确认后调 [AuthController.logout]；与 `_Sidebar._confirmLogout`
  /// 走同一条「弹窗 + 注销 + go_router redirect 回 /login」流程。
  /// 弹层在登录态变 false 后会随 redirect 一起被卸载，无需手动 pop。
  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定退出当前账号？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // isLoggedIn 变 false → go_router redirect 自动跳 /login → 弹层随之卸载。
    await ref.read(authControllerProvider.notifier).logout();
  }

  /// 右侧内容区：根据 [SettingsCategory] 选择对应屏幕 / 占位。
  /// 若当前展开了二级页（[_subPage]）则优先显示它。
  Widget _buildContent(ColorScheme scheme) {
    final sub = _subPage;
    if (sub != null) return sub;

    switch (_selected) {
      // 5 项已实现：直接复用项目内已有的 Screen（其内部已有 Scaffold + AppBar，
      // AppBar 标题 = 当前分类名，与对话舱的视觉习惯保持一致）。
      case SettingsCategory.accountMgmt:
        return const SettingsScreen();
      case SettingsCategory.dataMgmt:
        return const DataManagementScreen();
      case SettingsCategory.appearance:
        return const AppearanceScreen();
      case SettingsCategory.privacy:
        // 「长期记忆设置」是二级页：在弹层内原地展开，不关弹层、不走路由。
        // 页内 AppBar 的返回键回调 [_closeSubPage]，退回「隐私与权限」。
        return PrivacyScreen(
          onMemoryTap: () => _openSubPage(
            MemoryScreen(onBack: _closeSubPage),
          ),
        );
      case SettingsCategory.feedback:
        return const FeedbackScreen();

      // 「检查更新 / 服务协议」是动作型菜单（原 _Sidebar 里走的是 snackbar
      // 提示），这里改成右侧给「该分类正在开发中」占位，跟弹层整体风格统一。
      case SettingsCategory.checkUpdate:
      case SettingsCategory.tos:
        return _PlaceholderPage(category: _selected);

      // logout 是动作项（不进入 _select 选中态），不会走到这里。
      case SettingsCategory.logout:
        return const SizedBox.shrink();
    }
  }
}

/// 通用「即将上线」占位页：复用全部已主题化的 ColorScheme，避免临时排版。
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.category});
  final SettingsCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        // 内嵌屏幕的 leading 是动态的（桌面隐藏、移动端返回）：这里永远用空，
        // 因为弹层最外层的 (×) 已经足够关掉对话框，避免双层返回键。
        leading: const SizedBox.shrink(),
        title: Text(category.title, style: TextStyle(color: scheme.onSurface)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                '${category.title} 正在开发中',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '该分类的设置项将在后续版本陆续上线。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
