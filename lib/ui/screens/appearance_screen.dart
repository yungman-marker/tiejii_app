import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/theme_provider.dart';

/// 外观主题（/me/appearance）：浅色 / 深色 / 跟随系统 三选一。
///
/// 选择写入 [sharedPreferencesProvider] 注入的 [SharedPreferences]，
/// [themeModeProvider] 立即生效；下次冷启动恢复选择。
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isWide = isDesktop(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: isWide
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: const Text('外观主题'),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _sectionLabel('主题模式'),
            _optionsCard(mode, ref, scheme),
            const SizedBox(height: 18),
            _sectionLabel('说明'),
            _tip(
              '切换后立即生效。'
              '当前 app 已统一接入 Material 3 ColorScheme（Theme.of(context).colorScheme.*），'
              '绝大多数界面会跟随主题切换；个别硬编码色（AppColors 浅色调）'
              '是历史遗留，后续会逐步迁移为 ColorScheme。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Builder(builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
        );
      });

  Widget _optionsCard(ThemeMode mode, WidgetRef ref, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          _tile(
            icon: Icons.light_mode_outlined,
            label: '浅色',
            value: ThemeMode.light,
            groupValue: mode,
            scheme: scheme,
            onChanged: (v) =>
                v != null ? ref.read(themeModeProvider.notifier).set(v) : null,
          ),
          Divider(height: 1, color: scheme.outlineVariant, indent: 50),
          _tile(
            icon: Icons.dark_mode_outlined,
            label: '深色',
            value: ThemeMode.dark,
            groupValue: mode,
            scheme: scheme,
            onChanged: (v) =>
                v != null ? ref.read(themeModeProvider.notifier).set(v) : null,
          ),
          Divider(height: 1, color: scheme.outlineVariant, indent: 50),
          _tile(
            icon: Icons.brightness_auto_outlined,
            label: '跟随系统',
            value: ThemeMode.system,
            groupValue: mode,
            scheme: scheme,
            onChanged: (v) =>
                v != null ? ref.read(themeModeProvider.notifier).set(v) : null,
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required ThemeMode value,
    required ThemeMode groupValue,
    required ColorScheme scheme,
    required ValueChanged<ThemeMode?> onChanged,
  }) {
    final selected = value == groupValue;
    final fg = selected ? scheme.primary : scheme.onSurface;
    final iconClr = selected ? scheme.primary : scheme.onSurfaceVariant;
    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: Icon(
        icon,
        size: 20,
        color: iconClr,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: fg,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      activeColor: scheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    );
  }

  Widget _tip(String text) => Builder(builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: scheme.outline),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        );
      });
}
