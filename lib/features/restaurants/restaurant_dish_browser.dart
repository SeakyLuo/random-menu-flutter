import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'restaurant_dish_card.dart';
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
    if (dishes.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.ramen_dining_outlined,
          title: '还没有记录菜品',
          message: '记录消费后，这里会自动汇总吃过的菜。',
          actionLabel: '添加消费记录',
          onAction: () => editRestaurantVisit(context, restaurant),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.crossAxisExtent >= 600 ? 2 : 1;
          return SliverMasonryGrid.count(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 24,
            childCount: dishes.length,
            itemBuilder: (context, index) {
              final dish = dishes[index];
              return RestaurantDishCard(
                name: dish.name,
                paths: dish.paths,
                price: dish.price,
                note: dish.note,
                package: dish.package,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RestaurantDishPage(
                      restaurantId: restaurant.id,
                      name: dish.name,
                      sourceVisitId: dish.history.first.visit.id,
                      sourceItemIndex: dish.history.first.index,
                    ),
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
