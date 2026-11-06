import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/library_widgets.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/photo_widget.dart';
import 'restaurant_entries.dart';
import 'restaurant_images.dart';

class RestaurantDishesPage extends StatelessWidget {
  const RestaurantDishesPage({super.key, required this.restaurantId});
  final String restaurantId;
  Future<void> _action(
    BuildContext context,
    String action,
    Restaurant restaurant,
    int index,
  ) async {
    final dish = restaurant.foods[index];
    if (action == 'edit') {
      await editRestaurantDish(context, restaurant, dish: dish);
      return;
    }
    if (action == 'delete' &&
        !await confirmAction(
          context,
          title: '删除菜品？',
          message: '删除“${dish.name}”。已有用餐记录中的菜品快照会保留。',
        )) {
      return;
    }
    if (!context.mounted) return;
    await performAction(
      context,
      () => MenuScope.of(context).update((d) {
        final foods = d.restaurants
            .firstWhere((r) => r.id == restaurantId)
            .foods;
        final food = foods.removeAt(index);
        if (action != 'delete') {
          foods.insert(action == 'up' ? index - 1 : index + 1, food);
        }
      }),
      success: action == 'delete' ? '菜品已删除' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = MenuScope.of(
      context,
    ).data.restaurants.firstWhere((r) => r.id == restaurantId);
    return Scaffold(
      appBar: AppBar(title: Text('菜品资料 · ${r.foods.length}')),
      body: Stack(
        children: [
          r.foods.isEmpty
              ? EmptyState(
                  icon: Icons.ramen_dining_outlined,
                  title: '还没有菜品资料',
                  message: '记下招牌菜，下次点单更轻松。',
                  actionLabel: '添加第一道菜',
                  onAction: () => editRestaurantDish(context, r),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  itemCount: r.foods.length,
                  itemBuilder: (_, index) {
                    final dish = r.foods[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: dish.imagePaths.isEmpty
                          ? const MenuIcon(Icons.soup_kitchen_outlined)
                          : SizedBox(
                              width: 56,
                              height: 56,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LocalPhoto(path: dish.imagePaths.first),
                              ),
                            ),
                      title: Text(dish.name),
                      subtitle: Text(
                        [
                          if (dish.price > 0) '¥${money(dish.price)}',
                          if (dish.note.isNotEmpty) dish.note,
                        ].join(' · '),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RestaurantDishDetailPage(
                            restaurantId: r.id,
                            dishId: dish.id,
                          ),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: '菜品操作',
                        icon: const MenuIcon(Icons.more_horiz),
                        onSelected: (value) =>
                            _action(context, value, r, index),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('编辑菜品'),
                          ),
                          if (index > 0)
                            const PopupMenuItem(value: 'up', child: Text('上移')),
                          if (index < r.foods.length - 1)
                            const PopupMenuItem(
                              value: 'down',
                              child: Text('下移'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除菜品'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          LibraryFab(
            label: '添加菜品',
            bottom: 20,
            onPressed: () => editRestaurantDish(context, r),
          ),
        ],
      ),
    );
  }
}

class RestaurantDishDetailPage extends StatelessWidget {
  const RestaurantDishDetailPage({
    super.key,
    required this.restaurantId,
    required this.dishId,
  });
  final String restaurantId;
  final String dishId;
  @override
  Widget build(BuildContext context) {
    final restaurant = MenuScope.of(
      context,
    ).data.restaurants.firstWhere((r) => r.id == restaurantId);
    final dish = restaurant.foods.firstWhere((d) => d.id == dishId);
    return Scaffold(
      appBar: AppBar(
        title: Text(dish.name),
        actions: [
          IconButton(
            tooltip: '编辑菜品',
            onPressed: () =>
                editRestaurantDish(context, restaurant, dish: dish),
            icon: const MenuIcon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '¥${money(dish.price)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (dish.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(dish.note, style: const TextStyle(height: 1.6)),
            ),
          if (dish.imagePaths.isNotEmpty)
            RestaurantImages(paths: dish.imagePaths),
        ],
      ),
    );
  }
}
