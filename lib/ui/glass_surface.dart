import 'dart:ui';
import 'package:flutter/material.dart';

// Adapted from Aurai's glass surface: clipped blur, fine highlights, soft shadow.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 32,
    this.borderRadius,
    this.blurSigma = 16,
    this.color,
    this.borderColor,
    this.dark = false,
    this.regular = false,
    this.tintOpacity = 1,
    this.shadowOpacity = 1,
    this.gradientColors,
  });
  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final Color? color;
  final Color? borderColor;
  final bool dark;
  final bool regular;
  final double tintOpacity;
  final double shadowOpacity;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: borderRadius ?? BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: const Color(
            0x10000000,
          ).withValues(alpha: 16 / 255 * shadowOpacity),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: const Color(
            0x04000000,
          ).withValues(alpha: 4 / 255 * shadowOpacity),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(radius),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(radius),
            border: Border.all(
              color:
                  borderColor ??
                  ((dark || Theme.of(context).brightness == Brightness.dark)
                      ? const Color(0x38ffffff)
                      : const Color(0xcfffffff)),
              width: 1,
            ),
            color: color,
            gradient: color != null
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        (gradientColors ??
                                (regular
                                    ? (dark ||
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                          ? const [
                                              Color(0xf238383a),
                                              Color(0xeb303032),
                                              Color(0xf2333335),
                                            ]
                                          : const [
                                              Color(0xfaffffff),
                                              Color(0xf2ffffff),
                                              Color(0xf7f8f8fa),
                                            ])
                                    : (dark ||
                                          Theme.of(context).brightness ==
                                              Brightness.dark)
                                    ? const [
                                        Color(0xb348484b),
                                        Color(0x99202023),
                                        Color(0xc22b2b2e),
                                      ]
                                    : const [
                                        Color(0xe0ffffff),
                                        Color(0xb8ffffff),
                                        Color(0xccf2effa),
                                      ]))
                            .map(
                              (color) => color.withValues(
                                alpha: color.a * tintOpacity,
                              ),
                            )
                            .toList(),
                  ),
          ),
          child: RepaintBoundary(child: child),
        ),
      ),
    ),
  );
}
