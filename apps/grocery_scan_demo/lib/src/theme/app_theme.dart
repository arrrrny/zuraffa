import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Dark "camera" theme used across the whole mock app.
///
/// Emerald-on-ink palette tuned for a camera viewfinder: near-black green
/// background so store shelves read as ambient, and a fresh grocery-green
/// primary for CTAs and highlights.
abstract final class AppTheme {
  static const Color background = Color(0xFF070B09);
  static const Color backgroundRaised = Color(0xFF0C120F);
  static const Color foreground = Color(0xFFF2F7F3);
  static const Color primary = Color(0xFF34D399);
  static const Color primaryForeground = Color(0xFF06251A);
  static const Color muted = Color(0xFF161D19);
  static const Color mutedForeground = Color(0xFF8FA39A);
  static const Color accent = Color(0xFF6EE7B7);
  static const Color border = Color(0xFF22302A);
  static const Color ring = Color(0xFF34D399);
  static const Color destructive = Color(0xFFF87171);
  static const Color walmartBlue = Color(0xFF0071CE);
  static const Color albertsonsRed = Color(0xFFC8102E);

  /// shadcn_ui token set (what every Shad* component consumes).
  static final ShadColorScheme colorScheme = ShadColorScheme(
    background: background,
    foreground: foreground,
    card: backgroundRaised,
    cardForeground: foreground,
    popover: Color(0xFF101814),
    popoverForeground: foreground,
    primary: primary,
    primaryForeground: primaryForeground,
    secondary: muted,
    secondaryForeground: foreground,
    muted: muted,
    mutedForeground: mutedForeground,
    accent: accent,
    accentForeground: primaryForeground,
    destructive: destructive,
    destructiveForeground: Color(0xFF1A0505),
    border: border,
    input: border,
    ring: ring,
    selection: primary.withValues(alpha: 0.35),
  );

  static final ShadThemeData darkCameraTheme = ShadThemeData(
    colorScheme: colorScheme,
    brightness: Brightness.dark,
    radius: BorderRadius.circular(14),
  );

  static final ThemeData materialTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.dark(
      surface: backgroundRaised,
      primary: primary,
      onPrimary: primaryForeground,
      secondary: muted,
      onSecondary: foreground,
      onSurface: foreground,
      error: destructive,
    ),
    splashFactory: NoSplash.splashFactory,
    fontFamily: null,
  );
}
