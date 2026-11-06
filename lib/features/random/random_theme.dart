import 'package:flutter/material.dart';

ThemeData randomHomeTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: dark ? const Color(0xff83d8ac) : const Color(0xff088b62),
      onPrimary: dark ? const Color(0xff073922) : Colors.white,
      surface: dark ? const Color(0xff17241e) : Colors.white,
      onSurface: dark ? const Color(0xffe0e9e0) : const Color(0xff111720),
      onSurfaceVariant: dark
          ? const Color(0xffb1c1b5)
          : const Color(0xff747d8c),
      outlineVariant: dark ? const Color(0xff34453b) : const Color(0xffe9ecef),
    ),
  );
}
