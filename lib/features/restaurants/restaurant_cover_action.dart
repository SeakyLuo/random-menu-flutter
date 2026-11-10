import 'package:flutter/widgets.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';

Future<bool> setRestaurantCover(
  BuildContext context,
  String restaurantId,
  String? dishId,
) => performAction(
  context,
  () => MenuScope.of(context).update(MenuWriteScope.restaurant(restaurantId), (
    data,
  ) {
    final restaurant = data.restaurants.firstWhere(
      (restaurant) => restaurant.id == restaurantId,
    );
    if (dishId != null) {
      restaurant.records
          .expand((visit) => visit.items)
          .firstWhere(
            (dish) =>
                dish.dishId == dishId &&
                dish.isDish &&
                dish.imagePaths.isNotEmpty,
          );
    }
    restaurant.coverDishId = dishId;
  }),
  success: dishId == null ? '已取消设为封面' : '已设为餐厅封面',
);
