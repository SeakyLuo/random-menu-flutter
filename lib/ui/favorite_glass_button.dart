import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'menu_icon.dart';

class FavoriteGlassButton extends StatelessWidget {
  const FavoriteGlassButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.size = 34,
    this.iconSize = 21,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: size / 2,
    blurSigma: 24,
    color: const Color(0x25ffffff),
    borderColor: const Color(0x48ffffff),
    child: SizedBox.square(
      dimension: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: MenuIcon(
          Icons.favorite,
          size: iconSize,
          color: const Color(0xffef4762),
        ),
      ),
    ),
  );
}
