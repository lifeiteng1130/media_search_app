import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF6C63FF);
  static const surfaceColor = Color(0xFF1E1E2E);
  static const backgroundColor = Color(0xFF121220);

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardTheme: const CardTheme(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surfaceColor,
      indicatorColor: primaryColor.withOpacity(0.2),
    ),
  );
}
