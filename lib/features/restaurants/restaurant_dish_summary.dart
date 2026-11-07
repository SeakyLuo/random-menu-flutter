import '../../core/models.dart';

class RestaurantDishSummary {
  RestaurantDishSummary(this.name);
  final String name;
  RestaurantDish? saved;
  final history = <({Visit visit, VisitDish dish})>[];
  final paths = <String>[];
  double get price =>
      history.isNotEmpty ? history.first.dish.price : saved!.price;
  String get note {
    for (final entry in history) {
      if (entry.dish.note.isNotEmpty) return entry.dish.note;
    }
    return saved?.note ?? '';
  }

  int get visits => history.map((entry) => entry.visit.id).toSet().length;
}

List<RestaurantDishSummary> restaurantDishSummaries(Restaurant restaurant) {
  final dishes = <String, RestaurantDishSummary>{};
  final visits = [...restaurant.records]
    ..sort((a, b) => b.date.compareTo(a.date));
  for (final visit in visits) {
    for (final dish in visit.items) {
      final summary = dishes.putIfAbsent(
        dish.name,
        () => RestaurantDishSummary(dish.name),
      );
      summary.history.add((visit: visit, dish: dish));
      summary.paths.addAll(dish.imagePaths);
    }
  }
  for (final dish in restaurant.foods) {
    final summary = dishes.putIfAbsent(
      dish.name,
      () => RestaurantDishSummary(dish.name),
    );
    summary.saved = dish;
    summary.paths.addAll(dish.imagePaths);
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
