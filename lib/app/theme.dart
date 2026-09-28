import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF2B3A42);
  static const surface = Color(0xFF34464F);
  static const toBuy = Color(0xFFEE6A6A);
  static const recent = Color(0xFF6DB5A8);
  static const accent = Color(0xFF2E8B72);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        surface: AppColors.background,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: AppColors.background),
    );
