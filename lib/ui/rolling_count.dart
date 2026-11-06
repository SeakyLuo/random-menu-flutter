import 'package:flutter/material.dart';

class RollingCount extends StatelessWidget {
  const RollingCount({super.key, required this.value, this.style});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final number = Text('$value', key: ValueKey(value), style: style);
    if (MediaQuery.disableAnimationsOf(context)) return number;
    return Semantics(
      label: '$value',
      child: ExcludeSemantics(
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            reverseDuration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              final entering = child.key == ValueKey(value);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: Offset(0, entering ? 1 : -1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              );
            },
            child: number,
          ),
        ),
      ),
    );
  }
}
