import 'package:flutter/material.dart';

/// Цвета из макета «Аптека рядом». Две палитры: светлая и тёмная
/// (ночная, как в 2ГИС). Какая сейчас — решает [AppColors.dark].
abstract final class AppColors {
  /// Тёмная тема включена. Меняет [ThemeController] на корне приложения.
  static bool dark = false;

  static Color _p(int light, int night) => Color(dark ? night : light);

  static Color get green => _p(0xFF2E9F46, 0xFF3DB65A);
  static Color get greenDark => _p(0xFF217A35, 0xFF7FD493);
  /// Тёмно-зелёная заливка кнопок под белый текст (в обеих темах).
  static Color get greenFill => _p(0xFF217A35, 0xFF2A8C3F);
  static Color get greenSoft => _p(0xFFE3F4E6, 0xFF1D3526);
  static Color get background => _p(0xFFF3F7F5, 0xFF111614);
  static Color get surface => _p(0xFFFFFFFF, 0xFF1B2220);
  static Color get text => _p(0xFF17201B, 0xFFE7EEEA);
  static Color get textMuted => _p(0xFF5F6B64, 0xFF9AA8A1);
  static Color get border => _p(0xFFE4EAE6, 0xFF2B3531);
  static Color get orange => _p(0xFFB86A00, 0xFFF0A63F);
  static Color get orangeSoft => _p(0xFFFFEFD3, 0xFF3A2C15);
  static Color get greySoft => _p(0xFFE9ECEA, 0xFF29312E);
  static Color get userDot => const Color(0xFF2F7CF6);

  /// Белые «стеклянные» поверхности в светлой теме, тёмные — в ночной.
  static Color glass([double opacity = 1]) => (dark
          ? const Color(0xFF1B2220)
          : Colors.white)
      .withValues(alpha: opacity);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    brightness: AppColors.dark ? Brightness.dark : Brightness.light,
    primary: AppColors.green,
    surface: AppColors.surface,
    onSurface: AppColors.text,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.greenSoft,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.green
              : AppColors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.green
              : AppColors.textMuted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green,
        minimumSize: const Size(48, 52),
        side: BorderSide(color: AppColors.green, width: 1.5),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

const cardShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
];
