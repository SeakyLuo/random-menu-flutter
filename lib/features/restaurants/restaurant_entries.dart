import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/library_widgets.dart';
import 'restaurant_visit_editor.dart';

Future<void> editRestaurantVisit(
  BuildContext context,
  Restaurant restaurant, {
  Visit? visit,
}) => pushMenuEditor<void>(
  context,
  RestaurantVisitEditor(restaurant: restaurant, visit: visit),
);
