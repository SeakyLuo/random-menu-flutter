import 'dart:math' as math;
import 'package:flutter/material.dart';

class LibraryLayout {
  static const maxWidth = 1200.0;

  static bool _isIPad(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS &&
      MediaQuery.sizeOf(context).shortestSide >= 600;

  static int restaurantColumns(BuildContext context, double contentWidth) {
    final desired = contentWidth + 32 < 600
        ? 1
        : _isIPad(context)
        ? 3
        : 2;
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final fitting = ((contentWidth + 16) / (180 * scale + 16)).floor();
    return math.min(desired, math.max(1, fitting));
  }

  static int recipeColumns(BuildContext context, double contentWidth) {
    final width = contentWidth + 32;
    final desired = width < 340
        ? 1
        : width < 600
        ? 2
        : _isIPad(context)
        ? 4
        : 3;
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(16) / 16,
    );
    final fitting = ((contentWidth + 14) / (130 * scale + 14)).floor();
    return math.min(desired, math.max(1, fitting));
  }
}
