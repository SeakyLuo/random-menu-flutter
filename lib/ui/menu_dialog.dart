import 'package:flutter/material.dart';
import 'glass_surface.dart';

class MenuDialog extends StatelessWidget {
  const MenuDialog({
    super.key,
    required this.title,
    this.description,
    this.content,
    required this.actions,
  });

  final String title;
  final String? description;
  final Widget? content;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GlassSurface(
          radius: 28,
          blurSigma: 24,
          tintOpacity: .85,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            description!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (content != null) ...[
                          const SizedBox(height: 16),
                          content!,
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum MenuDialogRole { primary, secondary, destructive }

class MenuDialogButton extends StatelessWidget {
  const MenuDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.role = MenuDialogRole.primary,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final MenuDialogRole role;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = switch (role) {
      MenuDialogRole.primary => colors.onPrimary,
      MenuDialogRole.secondary => colors.onSurface,
      MenuDialogRole.destructive => colors.error,
    };
    final background = switch (role) {
      MenuDialogRole.primary => colors.primary,
      MenuDialogRole.secondary => Color.alphaBlend(
        colors.onSurface.withValues(alpha: dark ? .14 : .08),
        colors.surface,
      ),
      MenuDialogRole.destructive => Color.alphaBlend(
        colors.error.withValues(alpha: dark ? .16 : .08),
        colors.surface,
      ),
    };
    return TextButton(
      onPressed: busy ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy) ...[
            SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
