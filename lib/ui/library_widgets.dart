import 'hero_sheet_route.dart';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'menu_icon.dart';

Future<T?> pushMenuEditor<T>(BuildContext context, Widget page) =>
    Navigator.push<T>(
      context,
      PageRouteBuilder<T>(
        pageBuilder: (_, _, _) => page,
        transitionDuration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 260,
        ),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );

Future<T?> showMenuDetail<T>(BuildContext context, Widget page) =>
    showHeroSheet<T>(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: SizedBox(
              height: min(
                MediaQuery.sizeOf(context).height * .88,
                constraints.maxHeight - keyboard,
              ),
              child: page,
            ),
          );
        },
      ),
    );

void scrollMenuToTop(BuildContext context, ScrollController controller) {
  if (!controller.hasClients) return;
  if (MediaQuery.disableAnimationsOf(context)) {
    controller.jumpTo(0);
  } else {
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}

class LibraryFab extends StatelessWidget {
  const LibraryFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.bottom = 90,
    this.size = 58,
  });
  final String label;
  final VoidCallback? onPressed;
  final double bottom;
  final double size;
  @override
  Widget build(BuildContext context) => Positioned(
    right: 20,
    bottom: bottom + MediaQuery.viewPaddingOf(context).bottom,
    child: SizedBox.square(
      dimension: size,
      child: FloatingActionButton(
        heroTag: null,
        tooltip: label,
        onPressed: onPressed,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 3,
        shape: const CircleBorder(),
        child: const MenuIcon(Icons.add, size: 30),
      ),
    ),
  );
}

class PageActionButton extends StatelessWidget {
  const PageActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badgeCount = 0,
    this.size = 44,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final int badgeCount;
  final double size;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        color: badgeCount > 0 ? scheme.primary : scheme.onSurfaceVariant,
        icon: Badge(
          isLabelVisible: badgeCount > 0,
          label: Text('$badgeCount'),
          backgroundColor: scheme.primary,
          textColor: scheme.onPrimary,
          child: MenuIcon(icon, size: 22),
        ),
      ),
    );
  }
}

class PageAddButton extends StatelessWidget {
  const PageAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: onLongPress == null ? label : null,
        onPressed: onPressed,
        iconSize: 36,
        padding: const EdgeInsets.all(6),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: busy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : MenuIcon(Icons.add, size: 22, color: scheme.onPrimary),
          ),
        ),
      ),
    );
    if (onLongPress == null) return button;
    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.manual,
      child: GestureDetector(onLongPress: onLongPress, child: button),
    );
  }
}

class FixedPageActions extends StatelessWidget {
  const FixedPageActions({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Row(spacing: 12, children: children),
      ),
    ),
  );
}

class FormSection extends StatelessWidget {
  const FormSection(this.label, {super.key, required this.child, this.action});
  final String label;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}
