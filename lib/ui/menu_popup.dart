import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'menu_icon.dart';

class MenuPopupItem<T> {
  const MenuPopupItem({
    required this.value,
    required this.icon,
    required this.child,
    this.enabled = true,
    this.selected = false,
    this.destructive = false,
  });

  final T value;
  final IconData icon;
  final Widget child;
  final bool enabled;
  final bool selected;
  final bool destructive;
}

class MenuPopupButton<T> extends StatelessWidget {
  const MenuPopupButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    required this.tooltip,
    this.icon = const MenuIcon(Icons.more_horiz),
    this.child,
    this.buttonBuilder,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final List<MenuPopupItem<T>> Function(BuildContext) itemBuilder;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final Widget icon;
  final Widget? child;
  final Widget Function(VoidCallback open)? buttonBuilder;
  final bool enabled;
  final BorderRadius borderRadius;

  Future<void> _open(BuildContext context) async {
    final items = itemBuilder(context);
    final button = context.findRenderObject()! as RenderBox;
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchor =
        button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
    final media = MediaQuery.of(navigator.context).copyWith(size: overlay.size);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    final width = math.min(
      236.0,
      overlay.size.width - media.padding.horizontal - 16,
    );
    final left = (anchor.right - width).clamp(
      media.padding.left + 8,
      overlay.size.width - media.padding.right - width - 8,
    );
    final result = await showGeneralDialog<T>(
      context: context,
      requestFocus: false,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: Duration(
        milliseconds: media.disableAnimations ? 0 : 180,
      ),
      pageBuilder: (context, animation, _) {
        final curve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return themes.wrap(
          CustomSingleChildLayout(
            delegate: _MenuPosition(
              anchor: anchor,
              left: left,
              width: width,
              topInset: media.padding.top + 8,
              bottomInset:
                  math.max(media.padding.bottom, media.viewInsets.bottom) + 8,
            ),
            child: FadeTransition(
              opacity: curve,
              child: ScaleTransition(
                alignment: Alignment.topRight,
                scale: curve.drive(Tween(begin: .94, end: 1.0)),
                child: GlassSurface(
                  radius: 24,
                  blurSigma: 24,
                  tintOpacity: .85,
                  child: Material(
                    type: MaterialType.transparency,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(7),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final item in items)
                            _MenuRow<T>(
                              item: item,
                              onTap: () => Navigator.pop(context, item.value),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, _, _, child) => child,
    );
    if (context.mounted && result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (context) => buttonBuilder != null
        ? buttonBuilder!(() => _open(context))
        : child == null
        ? IconButton(
            tooltip: tooltip,
            onPressed: enabled ? () => _open(context) : null,
            icon: icon,
          )
        : Tooltip(
            message: tooltip,
            child: Semantics(
              button: true,
              enabled: enabled,
              child: InkWell(
                borderRadius: borderRadius,
                onTap: enabled ? () => _open(context) : null,
                child: child,
              ),
            ),
          ),
  );
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.item, required this.onTap});
  final MenuPopupItem<T> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = !item.enabled
        ? colors.onSurface.withValues(alpha: .38)
        : item.destructive
        ? colors.error
        : item.selected
        ? colors.primary
        : colors.onSurface;
    return Semantics(
      button: true,
      enabled: item.enabled,
      selected: item.selected,
      child: InkWell(
        onTap: item.enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        hoverColor: colors.primary.withValues(alpha: .05),
        highlightColor: colors.primary.withValues(alpha: .08),
        splashColor: colors.primary.withValues(alpha: .08),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                MenuIcon(item.icon, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                    child: item.child,
                  ),
                ),
                if (item.selected) ...[
                  const SizedBox(width: 10),
                  MenuIcon(Icons.check, size: 18, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuPosition extends SingleChildLayoutDelegate {
  const _MenuPosition({
    required this.anchor,
    required this.left,
    required this.width,
    required this.topInset,
    required this.bottomInset,
  });
  final Rect anchor;
  final double left, width, topInset, bottomInset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0, constraints.maxHeight - topInset - bottomInset),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = anchor.bottom + 8;
    final top = below + childSize.height <= size.height - bottomInset
        ? below
        : anchor.top - childSize.height - 8;
    return Offset(
      left,
      top.clamp(
        topInset,
        math.max(topInset, size.height - bottomInset - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_MenuPosition oldDelegate) =>
      anchor != oldDelegate.anchor ||
      left != oldDelegate.left ||
      width != oldDelegate.width ||
      topInset != oldDelegate.topInset ||
      bottomInset != oldDelegate.bottomInset;
}
