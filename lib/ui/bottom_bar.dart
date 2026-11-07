import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'menu_icon.dart';

class MenuBottomBar extends StatelessWidget {
  const MenuBottomBar({
    super.key,
    required this.selected,
    required this.pages,
    required this.onSelected,
  });
  final int selected;
  final PageController pages;
  final ValueChanged<int> onSelected;
  static const items = [
    (Icons.casino_outlined, '随机'),
    (Icons.edit_note, '菜谱'),
    (Icons.restaurant, '餐厅'),
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) => AnimatedBuilder(
                            animation: pages,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: constraints.maxWidth / items.length,
                                height: constraints.maxHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.onSurface.withValues(
                                      alpha: .08,
                                    ),
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                              ),
                            ),
                            builder: (context, child) {
                              final page = pages.hasClients
                                  ? pages.page ?? pages.initialPage.toDouble()
                                  : pages.initialPage.toDouble();
                              return Transform.translate(
                                offset: Offset(
                                  page * constraints.maxWidth / items.length,
                                  0,
                                ),
                                child: child,
                              );
                            },
                          ),
                        ),
                      ),
                      Row(
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
