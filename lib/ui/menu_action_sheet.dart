import 'package:flutter/material.dart';
import 'menu_bottom_sheet.dart';
import 'menu_icon.dart';

class MenuSheetAction {
  const MenuSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive, selected;
}

class MenuSheetActions extends StatelessWidget {
  const MenuSheetActions({super.key, required this.actions});
  final List<MenuSheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, action) in actions.indexed) ...[
          Semantics(
            selected: action.selected,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: action.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 12,
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            (action.destructive ? colors.error : colors.primary)
                                .withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: MenuIcon(
                          action.icon,
                          size: 22,
                          color: action.destructive
                              ? colors.error
                              : colors.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        action.label,
                        style: TextStyle(
                          fontSize: 16,
                          color: action.destructive
                              ? colors.error
                              : action.selected
                              ? colors.primary
                              : colors.onSurface,
                        ),
                      ),
                    ),
                    MenuIcon(
                      action.selected ? Icons.check : Icons.chevron_right,
                      size: 18,
                      color: action.destructive
                          ? colors.error
                          : action.selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (index < actions.length - 1)
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: .4),
            ),
        ],
      ],
    );
  }
}

Future<T?> showMenuActionSheet<T>({
  required BuildContext context,
  required String title,
  required List<MenuSheetAction> Function(BuildContext context) actions,
}) => showMenuBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  useSafeArea: true,
  builder: (context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: MenuIcon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            MenuSheetActions(actions: actions(context)),
          ],
        ),
      ),
    ),
  ),
);
