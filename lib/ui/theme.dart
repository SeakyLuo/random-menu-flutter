import 'package:flutter/services.dart';
import 'menu_icon.dart';
import 'package:flutter/material.dart';

SystemUiOverlayStyle menuSystemUiStyle(Brightness brightness) =>
    (brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        );

const leafGreen = Color(0xff27835d);

ThemeData menuTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: leafGreen,
    brightness: brightness,
    primary: dark ? const Color(0xff83d8ac) : leafGreen,
    surface: dark ? const Color(0xff17241e) : const Color(0xfffafcf9),
  );
  return ThemeData(
    useMaterial3: true,
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => const MenuIcon(Icons.arrow_back),
      closeButtonIconBuilder: (context) => const MenuIcon(Icons.close),
      drawerButtonIconBuilder: (context) =>
          const MenuIcon(Icons.menu_book_outlined),
      endDrawerButtonIconBuilder: (context) =>
          const MenuIcon(Icons.menu_book_outlined),
    ),
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xff111c17)
        : const Color(0xfff5f8f3),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: menuSystemUiStyle(brightness),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .45),
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
