import 'package:flutter/material.dart';
import 'menu_icon.dart';
import 'menu_tag_colors.dart';

class MenuTag extends StatelessWidget {
  const MenuTag(
    this.label, {
    super.key,
    this.onRemove,
    this.removable = false,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onRemove;
  final bool removable;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = MenuTagColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: EdgeInsets.fromLTRB(13, 4, removable ? 4 : 13, 4),
      decoration: BoxDecoration(
        color: selected ? primary.withValues(alpha: .10) : colors.background,
        border: Border.all(
          color: selected ? primary.withValues(alpha: .45) : colors.border,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: selected ? primary : colors.foreground,
              ),
            ),
          ),
          if (removable)
            SizedBox.square(
              dimension: 24,
              child: IconButton(
                tooltip: '移除标签$label',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onRemove,
                icon: MenuIcon(Icons.close, size: 14, color: colors.foreground),
              ),
            ),
        ],
      ),
    );
  }
}
