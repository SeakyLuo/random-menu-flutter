import '../../core/models.dart';

class RestaurantDishSummary {
  RestaurantDishSummary(this.name);
  final String name;
  final history = <({Visit visit, VisitDish dish, int index})>[];
  final paths = <String>[];
  double get price => package == null ? history.first.dish.price : 0;
  VisitPackage? get package =>
      history.first.visit.packageFor(history.first.dish);
  String get note {
    for (final entry in history) {
      if (entry.dish.note.isNotEmpty) return entry.dish.note;
    }
    return '';
  }

  int get visits => history.map((entry) => entry.visit.id).toSet().length;
}

List<RestaurantDishSummary> restaurantDishSummaries(
  Restaurant restaurant, {
  bool includeNonDishes = false,
}) {
  final dishes = <Object, RestaurantDishSummary>{};
  final visits = [...restaurant.records]
    ..sort((a, b) => b.date.compareTo(a.date));
  for (final visit in visits) {
    for (final (index, dish) in visit.items.indexed) {
      if (!includeNonDishes && !dish.isDish) continue;
      final summary = dishes.putIfAbsent(
        dish.name.isEmpty ? (visit.id, index) : dish.name,
        () => RestaurantDishSummary(dish.name),
      );
      summary.history.add((visit: visit, dish: dish, index: index));
      summary.paths.addAll(dish.imagePaths);
    }
  }
  for (final summary in dishes.values) {
    final unique = summary.paths.toSet().toList();
    summary.paths
      ..clear()
      ..addAll(unique);
  }
  return [
    ...dishes.values.where((dish) => dish.paths.isNotEmpty),
    ...dishes.values.where((dish) => dish.paths.isEmpty),
  ];
}
