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

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
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
