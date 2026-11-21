import 'package:material_ui/material_ui.dart';

/// AralMap brand palette.
///
/// [textSecondary] is darkened from the original #718096, which only reaches
/// ~3.9:1 contrast on [background]; #5F6B7A reaches ~5.3:1 (WCAG AA for body text).
abstract final class AppColors {
  static const primary = Color(0xFF287E72);
  static const background = Color(0xFFF5F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF263238);
  static const textSecondary = Color(0xFF5F6B7A);
  static const accent = Color(0xFFE7A857);
  static const outline = Color(0xFFDDE3E1);
  static const error = Color(0xFFC0392B);
}
