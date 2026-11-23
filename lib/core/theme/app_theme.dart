import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const double radius = 16;

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.accent,
          onSecondary: AppColors.textPrimary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.outline,
          error: AppColors.error,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      // White tab bar like the map buttons: no pill indicator, the selected
      // tab is shown by colour alone.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.06),
        ),
        elevation: 0,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme() {
    const base = TextStyle(color: AppColors.textPrimary);
    return TextTheme(
      headlineSmall: base.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      titleLarge: base.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: base.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: base.copyWith(fontSize: 16, height: 1.4),
      bodyMedium: base.copyWith(fontSize: 14, height: 1.4),
      bodySmall: base.copyWith(
        fontSize: 12,
        height: 1.4,
        color: AppColors.textSecondary,
      ),
      labelLarge: base.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }
}
