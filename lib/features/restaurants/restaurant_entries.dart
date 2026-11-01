import 'package:flutter/material.dart';
import '../../core/models.dart';
import 'restaurant_dish_editor.dart';
import 'restaurant_visit_editor.dart';

Future<void> editRestaurantDish(
  BuildContext context,
  Restaurant restaurant, {
  RestaurantDish? dish,
}) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) =>
        RestaurantDishEditor(restaurantId: restaurant.id, dish: dish),
  ),
);
Future<void> editRestaurantVisit(
  BuildContext context,
  Restaurant restaurant, {
  Visit? visit,
}) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => RestaurantVisitEditor(restaurant: restaurant, visit: visit),
  ),
);
