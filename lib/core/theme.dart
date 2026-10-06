import 'package:flutter/material.dart';

class MS {
  static const bg = Color(0xFF0A1220);
  static const surface = Color(0xFF121D31);
  static const accent = Color(0xFF22D3EE);
  static const ok = Color(0xFF22C55E);
  static const bad = Color(0xFFEF4444);

  static ThemeData theme() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: accent, surface: surface),
        useMaterial3: true,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: bg,
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
}
