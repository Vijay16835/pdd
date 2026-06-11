import 'package:flutter/material.dart';

/// Reactive color palette for LexGuard AI.
///
/// Screens use `AppColors.background`, `AppColors.cardDark`, etc. directly.
/// Call [AppColors.setDarkMode] from [ProfileProvider] whenever the theme
/// changes; all getters will immediately return the correct palette colour so
/// every screen re-renders correctly without any per-widget changes.
class AppColors {
  AppColors._();

  // ── Theme flag ──────────────────────────────────────────────────────────────
  static bool _isDark = true;

  /// Must be called from [ProfileProvider.toggleDarkMode] and on app startup
  /// (after loading SharedPreferences) so that all colour getters reflect the
  /// persisted preference.
  static void setDarkMode(bool value) => _isDark = value;
  static bool get isDark => _isDark;

  // ── Primary Brand Colors (always the same) ───────────────────────────────
  static const Color navy       = Color(0xFF0A1628);
  static const Color navyMid    = Color(0xFF0D1F3C);
  static const Color navyLight  = Color(0xFF162544);
  static const Color navyAccent = Color(0xFF1E3A6E);

  // ── Gold Accent Colors (always the same) ─────────────────────────────────
  static const Color gold      = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFE8C06A);
  static const Color goldDark  = Color(0xFFB8902E);
  static const Color goldGlow  = Color(0x33D4A843);

  // ── Adaptive Background Colors ───────────────────────────────────────────
  static Color get background => _isDark
      ? const Color(0xFF080F1E)
      : const Color(0xFFF5F7FA);

  static Color get cardDark => _isDark
      ? const Color(0xFF0F1C2E)
      : const Color(0xFFFFFFFF);

  static Color get cardMid => _isDark
      ? const Color(0xFF132036)
      : const Color(0xFFF0F3F8);

  static Color get navBar => _isDark
      ? const Color(0xFF0A1628)
      : const Color(0xFFFFFFFF);

  static Color get inputBg => _isDark
      ? const Color(0xFF0D1F3C)
      : const Color(0xFFF0F3F8);

  // ── Adaptive Border & Divider ────────────────────────────────────────────
  static Color get border => _isDark
      ? const Color(0xFF1E3A6E)
      : const Color(0xFFDDE3EE);

  static Color get borderLight => _isDark
      ? const Color(0xFF243D6A)
      : const Color(0xFFE5EAF2);

  static Color get divider => _isDark
      ? const Color(0xFF162544)
      : const Color(0xFFDDE3EE);

  // ── Adaptive Text Colors ─────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF0A1628);
  static const Color textSecondaryLight = Color(0xFF4A6490);
  static const Color textPrimaryDark    = Color(0xFFF0F4FF);
  static const Color textSecondaryDark  = Color(0xFF8BA3CC);

  static Color get textPrimary => _isDark
      ? textPrimaryDark
      : textPrimaryLight;

  static Color get textSecondary => _isDark
      ? textSecondaryDark
      : textSecondaryLight;

  static Color get textHint => _isDark
      ? const Color(0xFF4A6490)
      : const Color(0xFF8BA3CC);

  // ── Status Colors (always the same) ─────────────────────────────────────
  static const Color success   = Color(0xFF2ECC71);
  static const Color successBg = Color(0x1A2ECC71);
  static const Color warning   = Color(0xFFF39C12);
  static const Color warningBg = Color(0x1AF39C12);
  static const Color error     = Color(0xFFE74C3C);
  static const Color errorBg   = Color(0x1AE74C3C);
  static const Color info      = Color(0xFF3498DB);
  static const Color infoBg    = Color(0x1A3498DB);

  // ── Risk Level Colors (always the same) ─────────────────────────────────
  static const Color lowRisk     = Color(0xFF2ECC71);
  static const Color lowRiskBg   = Color(0x1A2ECC71);
  static const Color mediumRisk  = Color(0xFFF39C12);
  static const Color mediumRiskBg = Color(0x1AF39C12);
  static const Color highRisk    = Color(0xFFE74C3C);
  static const Color highRiskBg  = Color(0x1AE74C3C);

  // ── Light Theme specific (kept for backward compat) ──────────────────────
  static const Color lightBackground = Color(0xFFF5F7FA);

  // ── Gradient Colors (always the same) ────────────────────────────────────
  static const List<Color> heroGradient = [
    Color(0xFF1E3A6E),
    Color(0xFF0A1628),
  ];

  static const List<Color> goldGradient = [
    Color(0xFFE8C06A),
    Color(0xFFD4A843),
  ];

  static const List<Color> navyGradient = [
    Color(0xFF0D1F3C),
    Color(0xFF080F1E),
  ];

  static const List<Color> successGradient = [
    Color(0xFF27AE60),
    Color(0xFF2ECC71),
  ];

  static const List<Color> warningGradient = [
    Color(0xFFE67E22),
    Color(0xFFF39C12),
  ];

  static const List<Color> errorGradient = [
    Color(0xFFC0392B),
    Color(0xFFE74C3C),
  ];
}
