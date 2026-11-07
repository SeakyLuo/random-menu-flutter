import 'package:flutter/material.dart';
import 'menu_icon.dart';

class MenuFieldLabel extends StatelessWidget {
  const MenuFieldLabel(
    this.text, {
    super.key,
    this.hint,
    this.isRequired = false,
    this.icon,
    this.trailing,
    this.bottomSpacing = 10,
    this.minHeight = 0,
  });
  final String text;
  final String? hint;
  final bool isRequired;
  final IconData? icon;
  final Widget? trailing;
  final double bottomSpacing;
  final double minHeight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottomSpacing),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Row(
        children: [
          if (icon != null) ...[
            MenuIcon(icon!, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isRequired)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (hint != null)
                    TextSpan(
                      text: '   $hint',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}
