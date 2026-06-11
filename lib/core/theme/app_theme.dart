import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.goldLight,
        surface: AppColors.cardDark,
        error: AppColors.error,
        onPrimary: AppColors.navy,
        onSecondary: AppColors.navy,
        onSurface: AppColors.textPrimaryDark,
      ),
      textTheme: _buildTextTheme(true),
      appBarTheme: _buildAppBarTheme(true),
      cardTheme: _buildCardTheme(true),
      elevatedButtonTheme: _buildElevatedButtonTheme(true),
      outlinedButtonTheme: _buildOutlinedButtonTheme(true),
      inputDecorationTheme: _buildInputDecorationTheme(true),
      dividerTheme: _buildDividerTheme(true),
      iconTheme: _buildIconTheme(true),
      bottomNavigationBarTheme: _buildBottomNavigationBarTheme(true),
      snackBarTheme: _buildSnackBarTheme(true),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.light(
        primary: AppColors.navyAccent,
        secondary: AppColors.gold,
        surface: AppColors.cardDark,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: AppColors.navy,
        onSurface: AppColors.textPrimaryLight,
      ),
      textTheme: _buildTextTheme(false),
      appBarTheme: _buildAppBarTheme(false),
      cardTheme: _buildCardTheme(false),
      elevatedButtonTheme: _buildElevatedButtonTheme(false),
      outlinedButtonTheme: _buildOutlinedButtonTheme(false),
      inputDecorationTheme: _buildInputDecorationTheme(false),
      dividerTheme: _buildDividerTheme(false),
      iconTheme: _buildIconTheme(false),
      bottomNavigationBarTheme: _buildBottomNavigationBarTheme(false),
      snackBarTheme: _buildSnackBarTheme(false),
    );
  }

  static TextTheme _buildTextTheme(bool isDark) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final hintColor = isDark ? const Color(0xFF4A6490) : const Color(0xFF8BA3CC);
    final goldColor = AppColors.gold;

    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: hintColor,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: goldColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: goldColor,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: goldColor,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme(bool isDark) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final bgColor = isDark ? const Color(0xFF080F1E) : const Color(0xFFF5F7FA);

    return AppBarTheme(
      backgroundColor: bgColor,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: textColor),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }

  static CardThemeData _buildCardTheme(bool isDark) {
    final cardColor = isDark ? const Color(0xFF0F1C2E) : const Color(0xFFFFFFFF);
    return CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(bool isDark) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(bool isDark) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.gold, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(bool isDark) {
    final inputBgColor = isDark ? const Color(0xFF0D1F3C) : const Color(0xFFF0F3F8);
    final borderColor = isDark ? const Color(0xFF1E3A6E) : const Color(0xFFDDE3EE);
    final hintColor = isDark ? const Color(0xFF4A6490) : const Color(0xFF8BA3CC);
    final secondaryColor = isDark ? const Color(0xFF8BA3CC) : const Color(0xFF4A6490);

    return InputDecorationTheme(
      filled: true,
      fillColor: inputBgColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: hintColor,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: secondaryColor,
      ),
    );
  }

  static DividerThemeData _buildDividerTheme(bool isDark) {
    final borderColor = isDark ? const Color(0xFF1E3A6E) : const Color(0xFFDDE3EE);
    return DividerThemeData(
      color: borderColor,
      thickness: 1,
    );
  }

  static IconThemeData _buildIconTheme(bool isDark) {
    final iconColor = isDark ? const Color(0xFF8BA3CC) : const Color(0xFF4A6490);
    return IconThemeData(
      color: iconColor,
    );
  }

  static BottomNavigationBarThemeData _buildBottomNavigationBarTheme(bool isDark) {
    final navBgColor = isDark ? const Color(0xFF0A1628) : const Color(0xFFFFFFFF);
    final hintColor = isDark ? const Color(0xFF4A6490) : const Color(0xFF8BA3CC);

    return BottomNavigationBarThemeData(
      backgroundColor: navBgColor,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: hintColor,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    );
  }

  static SnackBarThemeData _buildSnackBarTheme(bool isDark) {
    final cardColor = isDark ? const Color(0xFF0F1C2E) : const Color(0xFFFFFFFF);
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return SnackBarThemeData(
      backgroundColor: cardColor,
      contentTextStyle: GoogleFonts.inter(
        color: textColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    );
  }
}
