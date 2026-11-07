import 'package:flutter/material.dart';

/// Shared group styling for the personal page and its settings.
class MenuSettingsSection extends StatelessWidget {
  const MenuSettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.dividerInset = 58,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final double dividerInset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.only(left: dividerInset),
                    child: const Divider(),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
