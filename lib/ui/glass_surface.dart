import 'dart:ui';
import 'package:flutter/material.dart';

// Adapted from Aurai's glass surface: clipped blur, fine highlights, soft shadow.
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.radius = 30});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: dark ? const Color(0x38ffffff) : const Color(0xcfffffff),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color(0xb348484b),
                        Color(0x99202023),
                        Color(0xc22b2b2e),
                      ]
                    : const [
                        Color(0xe0ffffff),
                        Color(0xb8ffffff),
                        Color(0xccf2effa),
                      ],
              ),
            ),
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }
}
