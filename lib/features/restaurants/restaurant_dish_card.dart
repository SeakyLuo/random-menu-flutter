import 'package:flutter/material.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../../core/models.dart';
import 'restaurant_food_summary.dart';
import '../media/photo_widget.dart';

class RestaurantDishCard extends StatelessWidget {
  const RestaurantDishCard({
    super.key,
    required this.name,
    required this.paths,
    required this.price,
    required this.note,
    required this.onTap,
    this.quantity = 1,
    this.package,
  });

  final String name;
  final List<String> paths;
  final double price;
  final String note;
  final int quantity;
  final VisitPackage? package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '查看$name详情',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24172c21),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: paths.isEmpty
                      ? ColoredBox(
                          color: scheme.surfaceContainer,
                          child: Center(
                            child: MenuIcon(
                              Icons.ramen_dining_outlined,
                              size: 30,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : LocalPhoto(path: paths.first),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name.isEmpty ? '未命名菜品' : name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (package == null && price > 0) ...[
                  const SizedBox(width: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: '¥',
                          style: TextStyle(fontSize: 10),
                        ),
                        TextSpan(text: money(price)),
                        if (quantity > 1)
                          TextSpan(
                            text: ' × $quantity',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            if (note.isNotEmpty || package != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  note.isNotEmpty ? '“$note”' : visitPackageLabel(package!),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
