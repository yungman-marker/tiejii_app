import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/locale_provider.dart';

/// 语言（/me/language）：跟随系统 / 简体中文 / English 三选一。
///
/// 选择写入 [localeProvider]（SharedPreferences 持久化），[app] 顶层
/// MaterialApp.locale 立即跟随；下次冷启动恢复选择。
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
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
        title: const Text('语言'),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _sectionLabel('显示语言'),
            _optionsCard(current, ref, scheme),
            const SizedBox(height: 18),
            _sectionLabel('说明'),
            _tip(
              '切换后立即生效并自动保存。'
              '选择「跟随系统」将使用手机系统语言；选择具体语言后 App 顶部栏、'
              '系统控件（如返回、日期选择）等会切换语言。'
              '（注：App 内业务文案的逐条翻译为后续工作，当前以系统/框架层语言切换为主。）',
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

  Widget _optionsCard(Locale? current, WidgetRef ref, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        children: [
          _tile(
            icon: Icons.sync_outlined,
            label: '跟随系统',
            value: null,
            groupValue: current,
            scheme: scheme,
            onChanged: (v) => ref.read(localeProvider.notifier).set(v),
          ),
          Divider(height: 1, color: scheme.outlineVariant, indent: 50),
          _tile(
            icon: Icons.translate_outlined,
            label: '简体中文',
            value: const Locale('zh', 'CN'),
            groupValue: current,
            scheme: scheme,
            onChanged: (v) => ref.read(localeProvider.notifier).set(v),
          ),
          Divider(height: 1, color: scheme.outlineVariant, indent: 50),
          _tile(
            icon: Icons.language_outlined,
            label: 'English',
            value: const Locale('en', 'US'),
            groupValue: current,
            scheme: scheme,
            onChanged: (v) => ref.read(localeProvider.notifier).set(v),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    required Locale? value,
    required Locale? groupValue,
    required ColorScheme scheme,
    required ValueChanged<Locale?> onChanged,
  }) {
    final selected = value?.toString() == groupValue?.toString();
    final fg = selected ? scheme.primary : scheme.onSurface;
    final iconClr = selected ? scheme.primary : scheme.onSurfaceVariant;
    return RadioListTile<Locale?>(
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
