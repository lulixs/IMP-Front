import 'package:flutter/material.dart';

/// Grays from the wireframes, same values as the prototype's palette.
class AppColors {
  static const ink = Color(0xFF222222); // main text, dark fills
  static const ink2 = Color(0xFF555555); // secondary text
  static const ink3 = Color(0xFF8A8A8A); // notes under fields
  static const ink4 = Color(0xFFABABAB); // example text inside empty fields
  static const line = Color(0xFFBDBDBD); // card borders
  static const field = Color(0xFF9D9D9D); // text field borders
  static const panel = Color(0xFFE6E6E6); // setup and sign-in background, sidebar
  static const soft = Color(0xFFF3F3F3); // bottom bar
  static const card = Color(0xFFFFFFFF); // cards
  static const half = Color(0xFFA8A8A8); // "Half" part of the fullness bar
  static const barEmpty = Color(0xFFF4F4F4); // "Empty" part of the fullness bar
  static const barBorder = Color(0xFF9A9A9A); // fullness bar outline
}

ThemeData buildTheme() {
  OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      primary: AppColors.ink,
      onPrimary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.ink,
    ),
    fontFamily: 'Arial',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.ink4, fontStyle: FontStyle.italic),
      border: outline(AppColors.field, 1.5),
      enabledBorder: outline(AppColors.field, 1.5),
      focusedBorder: outline(AppColors.ink, 2),
    ),
  );
}
