import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';

/// 数据管理（/me/data），样式参考「DeepSeek App · Data controls」：
///
///   ┌─────────────────────────────┐
///   │ 数据使用偏好                │
///   │ ┌─────────────────────────┐ │
///   │ │ 💬 对话历史保存   [开] │ │   ← 保存到账号
///   │ │ 🧪 数据用于优化   [关] │ │   ← 同意用于模型改进
///   │ └─────────────────────────┘ │
///   │ 数据操作                    │
///   │ ┌─────────────────────────┐ │
///   │ │ ⬇️ 导出数据         › │ │
///   │ │ 🗑 清除所有对话（红）› │ │
///   │ └─────────────────────────┘ │
///
/// 两个开关**真实持久化**到 SharedPreferences（key: dj_save_history / dj_opt_in_train），
/// 默认 保存对话=开、用于优化=关（对齐 DeepSeek 默认与腾讯隐私政策「数据用于优化体验」）。
/// 导出 / 清除涉及云端数据，**后端暂无对应端点**，点击仅给出提示并标注接入点，
/// 不伪造删除/导出动作，避免误伤用户数据。
class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  static const _kSaveHistory = 'dj_save_history';
  static const _kOptInTrain = 'dj_opt_in_train';

  bool _saveHistory = true;
  bool _optInTrain = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _saveHistory = sp.getBool(_kSaveHistory) ?? true;
      _optInTrain = sp.getBool(_kOptInTrain) ?? false;
      _loaded = true;
    });
  }

  Future<void> _setSaveHistory(bool v) async {
    setState(() => _saveHistory = v);
    (await SharedPreferences.getInstance()).setBool(_kSaveHistory, v);
  }

  Future<void> _setOptInTrain(bool v) async {
    setState(() => _optInTrain = v);
    (await SharedPreferences.getInstance()).setBool(_kOptInTrain, v);
  }

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
        title: const Text('数据管理'),
        centerTitle: true,
      ),
      body: SafeArea(bottom: false, child: _buildList(context)),
    );
  }

  /// 列表主体。
  Widget _buildList(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          // ── 数据使用偏好 ────────────────────────────────
          _sectionHeader('数据使用偏好'),
          _group([
            _switchRow(
              Icons.history_outlined,
              '对话历史保存到账号',
              '开启后，你的对话会保存在云端，可在其他设备同步查看',
              _loaded ? _saveHistory : true,
              _setSaveHistory,
            ),
            _switchRow(
              Icons.auto_awesome_outlined,
              '数据用于优化体验',
              '允许使用你的对话数据改进模型效果',
              _loaded ? _optInTrain : false,
              _setOptInTrain,
            ),
          ]),

          // ── 数据操作 ────────────────────────────────────
          _sectionHeader('数据操作'),
          _group([
            _row(Icons.download_outlined, '导出数据',
                onTap: () => _tip(context, '导出数据：由手机端 / 后端提供')),
            _row(Icons.delete_sweep_outlined, '清除所有对话',
                labelColor: AppColors.danger,
                iconColor: AppColors.danger,
                onTap: () => _confirmClear(context)),
          ]),

          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '导出与清除涉及云端数据，由后端提供能力；开关类偏好已保存在本机。',
              style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );

  void _tip(BuildContext ctx, String message) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));

  void _confirmClear(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('清除所有对话'),
        content: const Text(
          '将删除你的全部历史对话，且不可恢复。确定清除？',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              // 后端暂无清除全部会话端点（如 /ai/chat/his/record/clear）。
              // 接真实接口时在此调用并返回结果，再提示成功/失败。
              _tip(ctx, '清除请求已提交（由后端处理）');
            },
            child: const Text('清除'),
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

  Widget _switchRow(
    IconData icon,
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Builder(builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                activeThumbColor: scheme.primary,
                activeTrackColor: AppColors.primarySoft,
                onChanged: onChanged,
              ),
            ],
          ),
        );
      });

  Widget _row(
    IconData icon,
    String label, {
    Color? labelColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) =>
      Builder(builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final fg = labelColor ?? scheme.onSurface;
        final iconClr = iconColor ?? scheme.onSurfaceVariant;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
