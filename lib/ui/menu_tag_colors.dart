import 'package:flutter/material.dart';

class MenuTagColors {
  const MenuTagColors(this.background, this.foreground, this.border);

  final Color background;
  final Color foreground;
  final Color border;

  static const light = MenuTagColors(
    Color(0xfff3f1ec),
    Color(0xff71685c),
    Color(0xffe4dfd5),
  );
  static const dark = MenuTagColors(
    Color(0xff2c2a25),
    Color(0xffd6cfc2),
    Color(0xff464139),
  );

  static MenuTagColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
