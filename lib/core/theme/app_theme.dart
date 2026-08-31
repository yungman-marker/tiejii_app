import 'package:flutter/material.dart';

/// 设计语言：千问 / DeepSeek 风格 —— 浅灰底 + 白卡 + 克制品牌色。
/// 视觉参照《铁骥原型_设计稿.html》，此处为独立实现（不复用原型代码）。
class AppColors {
  const AppColors._();

  static const background = Color(0xFFF4F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFC);

  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  static const divider = Color(0xFFF1F5F9);
  static const border = Color(0xFFE5E7EB);

  /// 中国铁建品牌蓝
  static const brandBlue = Color(0xFF0E5BBF);
  /// 主操作色（浅蓝胶囊按钮文字色）
  static const primary = Color(0xFF2554D6);
  /// 主操作浅底 rgba(77,124,255,.14)
  static const primarySoft = Color(0x244D7CFF);

  static const danger = Color(0xFFE60012);
  static const success = Color(0xFF16A34A);
  static const wechatGreen = Color(0xFF07C160);

  /// 半透明变体：用**显式 ARGB** 定义，避免依赖
  /// `withOpacity`（新版已废弃）或 `withValues`（旧版不存在）造成的版本兼容问题。
  static const dangerSoft = Color(0x14E60012); // 8%
  static const brandBlueSoft = Color(0x1A0E5BBF); // 10%
  static const wechatGreenSoft = Color(0x1A07C160); // 10%
}

class AppRadius {
  const AppRadius._();
  static const card = 14.0;
  static const bubble = 16.0;
  static const pill = 999.0;
}

/// 科技感设计令牌（HUD/Sci-Fi 风格，用于登录页等需要"AI/航天"质感的场景）。
///
/// 视觉参考 ui-ux-pro-max: HUD/Sci-Fi FUI + Glassmorphism + Aurora UI 三种风格融合。
/// 配色避开了赛博朋克的 Matrix 绿，转向更克制、更适合央企的"深空蓝 + 霓虹青"。
class TechColors {
  const TechColors._();

  // 深空背景层（从外到内）
  static const bgBase = Color(0xFF050816); // 页面底色
  static const bgPanel = Color(0xFF0A1024); // 桌面端右栏
  static const bgCard = Color(0xCC0F172A); // 玻璃卡（80% 不透明）
  static const bgInput = Color(0xFF0B1220); // 输入框填充

  // 霓虹/科技感强调色
  static const neonCyan = Color(0xFF00D9FF); // 主光（辉光、聚焦边框）
  static const neonBlue = Color(0xFF0080FF); // 次光（按钮渐变末端）
  static const neonPurple = Color(0xFF8B5CF6); // 装饰辉光

  // 中国铁建品牌蓝（保留品牌识别）
  static const brandBlue = Color(0xFF0E5BBF);

  // 文字（深色背景下）
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF64748B);

  // 边框
  static const border = Color(0xFF1E293B); // 默认 1px 暗边框
  static const borderSoft = Color(0xFF0F1B2E); // 更深的内嵌边框

  // 半透明变体（辉光阴影 / HUD 装饰线）
  static const glowCyanStrong = Color(0x6600D9FF); // ~40%
  static const glowCyanMid = Color(0x3300D9FF); // ~20%
  static const glowCyanSoft = Color(0x1A00D9FF); // ~10%
  static const gridLine = Color(0x14FFFFFF); // ~8% 白（HUD 网格线）
  static const scanLine = Color(0x08FFFFFF); // ~3% 白（细扫描线）
}

class AppTheme {
  const AppTheme._();

  /// 深色调色板（仅用于"主题切换"基础设施搭建，本轮只接 Material 默认色，
  /// 不重写所有 AppColors；后续把 AppColors 拆分 light/dark 两套时复用此色）。
  static const darkBackground = Color(0xFF0F1115);
  static const darkSurface = Color(0xFF1B1F27);
  static const darkSurfaceMuted = Color(0xFF14171D);
  static const darkTextPrimary = Color(0xFFE5E7EB);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkTextTertiary = Color(0xFF6B7280);
  static const darkDivider = Color(0xFF2A2F38);
  static const darkBorder = Color(0xFF2F343D);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF60A5FA),
        onPrimary: Color(0xFF0B1220),
        secondary: Color(0xFF60A5FA),
        onSecondary: Color(0xFF0B1220),
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: Color(0xFF232830),
        onSurfaceVariant: darkTextSecondary,
        outline: darkBorder,
        outlineVariant: darkDivider,
        error: Color(0xFFF87171),
        onError: Color(0xFF0B1220),
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle:
            const TextStyle(color: darkTextTertiary, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: Color(0xFF60A5FA)),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primary,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceMuted,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
        error: AppColors.danger,
        onError: Colors.white,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }
}
