import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'menu_icon.dart';

class MenuBottomBar extends StatelessWidget {
  const MenuBottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  static const items = [
    (Icons.shuffle, '随机'),
    (Icons.edit_note, '菜谱'),
    (Icons.storefront_outlined, '餐厅'),
    (Icons.person_outline_rounded, '我的'),
  ];
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelHeight = MediaQuery.textScalerOf(context).scale(12);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassSurface(
            radius: 30,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  height: 50 + labelHeight - 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: selected == i,
                            button: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(26),
                              onTap: () => onSelected(i),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  MenuIcon(
                                    items[i].$1,
                                    size: 24,
                                    color: selected == i
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    items[i].$2,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.2,
                                      color: selected == i
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                      fontWeight: selected == i
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
  }
}
