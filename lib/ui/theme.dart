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

const leafGreen = Color(0xff088b62);

ThemeData menuTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: leafGreen,
        brightness: brightness,
        primary: dark ? const Color(0xff83d8ac) : leafGreen,
        surface: dark ? const Color(0xff17241e) : Colors.white,
      ).copyWith(
        onSurface: dark ? const Color(0xffe0e9e0) : const Color(0xff111720),
        onSurfaceVariant: dark
            ? const Color(0xffb1c1b5)
            : const Color(0xff747d8c),
        outlineVariant: dark
            ? const Color(0xff34453b)
            : const Color(0xffe9ecef),
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
        : const Color(0xfff4f9f5),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: menuSystemUiStyle(brightness),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surface : const Color(0xfff6f7f8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: dark ? const Color(0xff56665c) : const Color(0xffd4d4d4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .45),
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
