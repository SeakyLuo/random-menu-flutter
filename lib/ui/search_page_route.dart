import 'package:flutter/material.dart';

Future<T?> pushSearchPage<T>(BuildContext context, Widget page) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return Navigator.push<T>(
    context,
    PageRouteBuilder<T>(
      allowSnapshotting: false,
      transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 300),
      reverseTransitionDuration: Duration(milliseconds: reduceMotion ? 0 : 220),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    ),
  );
}
