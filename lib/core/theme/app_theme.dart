import 'package:flutter/material.dart';

import 'app_colors.dart';

ThemeData createAppTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF070807),
  colorScheme: const ColorScheme.dark(primary: lime, surface: surface),
  useMaterial3: true,
  fontFamily: 'Kanit',
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: lime),
    ),
    labelStyle: const TextStyle(fontSize: 12),
    hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      foregroundColor: Colors.black,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: Colors.white70,
      side: const BorderSide(color: Colors.white12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: surface,
    showDragHandle: true,
  ),
  dividerColor: Colors.white10,
  dividerTheme: const DividerThemeData(color: Colors.white10, thickness: 1),
);
