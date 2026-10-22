// ThemeData Material 3 sáng / tối (dark mode theo hệ thống) từ ColorScheme.fromSeed tông xanh ngọc.
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: brightness);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radius));
    return base.copyWith(
      textTheme: AppText.textTheme(base.textTheme),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.textTheme(base.textTheme).titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: rounded,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52), // chỉ cố định chiều cao, rộng vô hạn sẽ vỡ layout trong ListTile và hộp thoại
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
          textStyle: const TextStyle(fontFamily: AppText.fontFamily, fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
          textStyle: const TextStyle(fontFamily: AppText.fontFamily, fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          const TextStyle(fontFamily: AppText.fontFamily, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant))),
    );
  }
}
