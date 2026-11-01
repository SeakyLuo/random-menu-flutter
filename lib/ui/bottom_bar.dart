import 'menu_icon.dart';
import 'package:flutter/material.dart';
import 'glass_surface.dart';

class MenuBottomBar extends StatelessWidget {
  const MenuBottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  static const items = [
    (Icons.casino_outlined, Icons.casino, '随机'),
    (Icons.menu_book_outlined, Icons.menu_book, '菜谱'),
    (Icons.storefront_outlined, Icons.storefront, '餐厅'),
    (Icons.person_outline_rounded, Icons.person_rounded, '我的'),
  ];
  @override
  Widget build(BuildContext context) => SafeArea(
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
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    left: selected * constraints.maxWidth / 4,
                    top: 0,
                    bottom: 0,
                    width: constraints.maxWidth / 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: selected == i,
                            button: true,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(26),
                                onTap: () => onSelected(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      MenuIcon(
                                        selected == i
                                            ? items[i].$2
                                            : items[i].$1,
                                        size: 24,
                                        color: selected == i
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        items[i].$3,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: selected == i
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: selected == i
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
