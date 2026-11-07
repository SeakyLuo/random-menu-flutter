import 'package:flutter/material.dart';
import 'menu_bottom_sheet.dart';

Future<T?> showHeroSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
}) => Navigator.of(context).push<T>(
  HeroSheetRoute<T>(
    builder: builder,
    constraints: constraints,
    label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    themes: InheritedTheme.capture(
      from: context,
      to: Navigator.of(context).context,
    ),
    reduceMotion: MediaQuery.disableAnimationsOf(context),
    scrimColor:
        Theme.of(context).bottomSheetTheme.modalBarrierColor ?? Colors.black54,
  ),
);

// PageRoute lets images in the sheet participate in Hero transitions.
class HeroSheetRoute<T> extends PageRoute<T> {
  HeroSheetRoute({
    required this.builder,
    required this.label,
    required this.themes,
    required this.constraints,
    required this.reduceMotion,
    required this.scrimColor,
  });

  final WidgetBuilder builder;
  final String label;
  final CapturedThemes themes;
  final BoxConstraints? constraints;
  final bool reduceMotion;
  final Color scrimColor;

  @override
  bool get opaque => false;
  @override
  bool get maintainState => true;
  @override
  bool get barrierDismissible => true;
  @override
  Color get barrierColor => scrimColor;
  @override
  String get barrierLabel => label;
  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 240);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(
    SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(0, 1), end: Offset.zero),
          ),
          child: BottomSheet(
            animationController: controller,
            showDragHandle: false,
            clipBehavior: Clip.antiAlias,
            constraints: constraints,
            backgroundColor: Theme.of(
              context,
            ).bottomSheetTheme.modalBackgroundColor,
            elevation: Theme.of(context).bottomSheetTheme.modalElevation,
            onClosing: () {
              if (isCurrent) navigator!.pop();
            },
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MenuSheetHandle(),
                Flexible(child: builder(context)),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
