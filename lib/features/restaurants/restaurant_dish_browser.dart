import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/photo_widget.dart';
import 'restaurant_dish_summary.dart';
import 'restaurant_dish_page.dart';
import 'restaurant_entries.dart';

class RestaurantDishSliver extends StatelessWidget {
  const RestaurantDishSliver({
    super.key,
    required this.restaurant,
    required this.dishes,
  });
  final Restaurant restaurant;
  final List<RestaurantDishSummary> dishes;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (dishes.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.ramen_dining_outlined,
          title: '还没有记录菜品',
          message: '记一次用餐，或先添加想点的菜。',
          actionLabel: '添加菜品',
          onAction: () => editRestaurantDish(context, restaurant),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.crossAxisExtent >= 600 ? 2 : 1;
          return SliverMasonryGrid.count(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
            childCount: dishes.length,
            itemBuilder: (context, index) {
              final dish = dishes[index];
              return Semantics(
                button: true,
                label: '查看${dish.name}详情',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RestaurantDishPage(
                        restaurantId: restaurant.id,
                        name: dish.name,
                        savedDishId: dish.saved?.id,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: dish.paths.isEmpty
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
                              : LocalPhoto(path: dish.paths.first),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              dish.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (dish.price > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '¥${money(dish.price)}',
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (dish.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            dish.note,
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
            },
          );
        },
      ),
    );
  }
}
