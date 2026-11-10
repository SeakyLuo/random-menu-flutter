import 'package:flutter/material.dart';
import 'library_widgets.dart';

class MenuTitleLine extends StatelessWidget {
  const MenuTitleLine({
    super.key,
    required this.children,
    this.mainAxisSize = MainAxisSize.max,
  });

  final List<Widget> children;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: mainAxisSize,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: children,
  );
}

class MenuScrollTitle extends StatelessWidget {
  const MenuScrollTitle({
    super.key,
    required this.child,
    this.controller,
    this.onTap,
  });

  final Widget child;
  final ScrollController? controller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          onTap ??
          () => scrollMenuToTop(
            context,
            controller ?? PrimaryScrollController.of(context),
          ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: child,
        ),
      ),
    ),
  );
}
