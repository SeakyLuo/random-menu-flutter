import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/photo_widget.dart';
import 'restaurant_dish_summary.dart';
import 'restaurant_dish_page.dart';
import 'restaurant_entries.dart';

class RestaurantDishBrowser extends StatefulWidget {
  const RestaurantDishBrowser({
    super.key,
    required this.restaurant,
    required this.dishes,
  });
  final Restaurant restaurant;
  final List<RestaurantDishSummary> dishes;
  @override
  State<RestaurantDishBrowser> createState() => _RestaurantDishBrowserState();
}

class _RestaurantDishBrowserState extends State<RestaurantDishBrowser>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dishes = widget.dishes;
    final scheme = Theme.of(context).colorScheme;
    if (dishes.isEmpty) {
      return EmptyState(
        icon: Icons.ramen_dining_outlined,
        title: '还没有记录菜品',
        message: '记一次用餐，或先添加想点的菜。',
        actionLabel: '添加菜品',
        onAction: () => editRestaurantDish(context, widget.restaurant),
      );
    }
    return CustomScrollView(
      key: PageStorageKey('restaurant-dishes:${widget.restaurant.id}'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.crossAxisExtent < 260
                  ? 1
                  : constraints.crossAxisExtent >= 600
                  ? 3
                  : 2;
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
                            restaurantId: widget.restaurant.id,
                            name: dish.name,
                            savedDishId: dish.saved?.id,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
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
                                    fontSize: 14,
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
                                    fontSize: 14,
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
        ),
      ],
    );
  }
}
