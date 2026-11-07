import 'menu_icon.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'menu_dialog.dart';

class MenuAppBar extends StatelessWidget {
  const MenuAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.compact = true,
    this.actionsSpacing = 8,
  });
  final String title;
  final List<Widget> actions;
  final bool compact;
  final double actionsSpacing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: compact ? 0 : 4),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 48 : 52),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 0 : 4),
        child: Row(
          spacing: actionsSpacing,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    ),
  );
}

class MenuPage extends StatelessWidget {
  const MenuPage({
    super.key,
    required this.title,
    this.actions = const [],
    this.compactHeader = true,
    this.actionsSpacing = 8,
    this.maxWidth = 600,
    required this.child,
  });
  final String title;
  final List<Widget> actions;
  final bool compactHeader;
  final double actionsSpacing;
  final double maxWidth;
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MenuAppBar(
                title: title,
                actions: actions,
                compact: compactHeader,
                actionsSpacing: actionsSpacing,
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 110),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: .4),
              shape: BoxShape.circle,
            ),
            child: MenuIcon(
              icon,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

OverlayEntry? _toast;
Timer? _toastTimer;
void showToast(BuildContext context, String message) {
  _toastTimer?.cancel();
  _toast?.remove();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 110,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Colors.transparent,
              child: GlassSurface(
                radius: 18,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Text(message, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _toast = entry;
  Overlay.of(context, rootOverlay: true).insert(entry);
  _toastTimer = Timer(const Duration(seconds: 3), () {
    entry.remove();
    _toast = null;
  });
}

Future<bool> performAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) showToast(context, success);
    return true;
  } catch (error, stack) {
    debugPrint('Menu action failed: $error\n$stack');
    if (context.mounted) showToast(context, '操作未完成，请重试');
    return false;
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
  bool destructive = true,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => MenuDialog(
        title: title,
        description: message,
        actions: Row(
          children: [
            Expanded(
              child: MenuDialogButton(
                label: '取消',
                role: MenuDialogRole.secondary,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MenuDialogButton(
                label: confirmLabel,
                role: destructive
                    ? MenuDialogRole.destructive
                    : MenuDialogRole.primary,
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
          ],
        ),
      ),
    ) ==
    true;

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

String money(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
String dayLabel(DateTime date) => '${date.year}年${date.month}月${date.day}日';
