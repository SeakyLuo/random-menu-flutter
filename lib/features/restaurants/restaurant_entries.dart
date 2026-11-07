import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/library_widgets.dart';
import 'restaurant_dish_editor.dart';
import 'restaurant_visit_editor.dart';

Future<void> editRestaurantDish(
  BuildContext context,
  Restaurant restaurant, {
  RestaurantDish? dish,
  String? initialName,
}) => pushMenuEditor<void>(
  context,
  RestaurantDishEditor(
    restaurantId: restaurant.id,
    dish: dish,
    initialName: initialName,
  ),
);
Future<void> editRestaurantVisit(
  BuildContext context,
  Restaurant restaurant, {
  Visit? visit,
}) => pushMenuEditor<void>(
  context,
  RestaurantVisitEditor(restaurant: restaurant, visit: visit),
);
