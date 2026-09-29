import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// App-specific design tokens, attached to both themes as a [ThemeExtension].
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.toBuy,
    required this.recent,
    required this.late,
    required this.lateTint,
    required this.onLateTint,
    required this.card,
    required this.cardBorder,
    required this.mutedText,
    this.cardRadius = 16,
    this.tileRadius = 20,
  });

  /// Shopping: To buy tiles (same in both themes).
  final Color toBuy;

  /// Shopping: Recently used tiles (same in both themes).
  final Color recent;

  /// Late chores: strong colour, light tint and text on the tint.
  final Color late;
  final Color lateTint;
  final Color onLateTint;

  /// Neutral cards on the calm screens.
  final Color card;
  final Color cardBorder;

  /// Secondary text; readable on [card] and on the page background.
  final Color mutedText;

  final double cardRadius;
  final double tileRadius;

  static const light = AppTokens(
    toBuy: Color(0xFFEE6A6A),
    recent: Color(0xFF6DB5A8),
    late: Color(0xFFA32D2D),
    lateTint: Color(0xFFFCEBEB),
    onLateTint: Color(0xFF791F1F),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE4E0D6),
    mutedText: Color(0xFF63625D),
  );

  static const dark = AppTokens(
    toBuy: Color(0xFFEE6A6A),
    recent: Color(0xFF6DB5A8),
    late: Color(0xFFF09595),
    lateTint: Color(0xFF791F1F),
    onLateTint: Color(0xFFFCEBEB),
    card: Color(0xFF283035),
    cardBorder: Color(0xFF3A444A),
    mutedText: Color(0xFFA9B1B6),
  );

  @override
  AppTokens copyWith({
    Color? toBuy,
    Color? recent,
    Color? late,
    Color? lateTint,
    Color? onLateTint,
    Color? card,
    Color? cardBorder,
    Color? mutedText,
    double? cardRadius,
    double? tileRadius,
  }) =>
      AppTokens(
        toBuy: toBuy ?? this.toBuy,
        recent: recent ?? this.recent,
        late: late ?? this.late,
        lateTint: lateTint ?? this.lateTint,
        onLateTint: onLateTint ?? this.onLateTint,
        card: card ?? this.card,
        cardBorder: cardBorder ?? this.cardBorder,
        mutedText: mutedText ?? this.mutedText,
        cardRadius: cardRadius ?? this.cardRadius,
        tileRadius: tileRadius ?? this.tileRadius,
      );

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      toBuy: Color.lerp(toBuy, other.toBuy, t)!,
      recent: Color.lerp(recent, other.recent, t)!,
      late: Color.lerp(late, other.late, t)!,
      lateTint: Color.lerp(lateTint, other.lateTint, t)!,
      onLateTint: Color.lerp(onLateTint, other.onLateTint, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      tileRadius: lerpDouble(tileRadius, other.tileRadius, t)!,
    );
  }
}

extension AppTokensContext on BuildContext {
  /// The app's tokens. Falls back to the defaults for the theme's brightness
  /// when a theme without [AppTokens] is in use (for example a bare test app).
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ??
        (theme.brightness == Brightness.dark ? AppTokens.dark : AppTokens.light);
  }
}

const _lightBackground = Color(0xFFF7F5F0);
const _darkBackground = Color(0xFF1E2326);
const _seed = Color(0xFF0F6E56); // palette teal, 600 stop

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final tokens = isDark ? AppTokens.dark : AppTokens.light;
  final background = isDark ? _darkBackground : _lightBackground;
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
    surface: background,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'IBMPlexSansArabic',
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: tokens.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        side: BorderSide(color: tokens.cardBorder),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
    ),
    extensions: [tokens],
  );
}
