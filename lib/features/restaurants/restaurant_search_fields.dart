import '../../core/models.dart';
import 'restaurant_dish_summary.dart';
import 'restaurant_filter.dart';
import 'restaurant_search.dart';
import 'restaurants_page.dart' show orderedRestaurants;

enum RestaurantSearchField { all, restaurants, dishes }

class RestaurantSearchHit {
  const RestaurantSearchHit(this.restaurant, this.context, {this.visit});
  final Restaurant restaurant;
  final String? context;
  final Visit? visit;
}

class RestaurantDishHit {
  const RestaurantDishHit(this.restaurant, this.dish, this.note);
  final Restaurant restaurant;
  final RestaurantDishSummary dish;
  final String? note;
}

class RestaurantSearchMatches {
  final restaurants = <RestaurantSearchHit>[];
  final dishes = <RestaurantDishHit>[];

  int count(RestaurantSearchField field) => switch (field) {
    RestaurantSearchField.all => restaurants.length + dishes.length,
    RestaurantSearchField.restaurants => restaurants.length,
    RestaurantSearchField.dishes => dishes.length,
  };
}

RestaurantSearchMatches searchRestaurantContents(
  List<Restaurant> restaurants,
  String query,
) {
  final result = RestaurantSearchMatches();
  if (query.isEmpty) return result;
  final term = query.toLowerCase();
  bool matches(String value) => value.toLowerCase().contains(term);
  for (final restaurant in orderedRestaurants(
    restaurants,
    RestaurantSort.recent,
  )) {
    final fields = [
      ...restaurant.categories,
      ...restaurant.addressEntries.map((address) => address.fullAddress),
      ...restaurant.addresses,
      ...restaurant.records.map((visit) => visit.address),
      restaurant.note,
    ];
    final visits =
        restaurant.records.where((visit) => matches(visit.note)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final reviewVisit = visits.firstOrNull;
    final context = matches(restaurant.note)
        ? restaurant.note
        : reviewVisit != null
        ? reviewVisit.note
        : matches(restaurant.name)
        ? null
        : fields.where(matches).firstOrNull;
    if (matches(restaurant.name) || context != null) {
      result.restaurants.add(
        RestaurantSearchHit(
          restaurant,
          context,
          visit: matches(restaurant.note) ? null : reviewVisit,
        ),
      );
    }
    for (final dish in restaurantDishSummaries(restaurant)) {
      final notes = [...dish.history.map((entry) => entry.dish.note)];
      final note = notes.where(matches).firstOrNull;
      if (matches(dish.name) || note != null) {
        result.dishes.add(RestaurantDishHit(restaurant, dish, note));
      }
    }
  }
  _rank(
    result.restaurants,
    (hit) => restaurantSearchScore(hit.restaurant, query),
  );
  _rank(
    result.dishes,
    (hit) => restaurantDishSearchScore(hit.dish.name, [
      ...hit.dish.history.map((entry) => entry.dish.note),
    ], query),
  );
  return result;
}

void _rank<T>(List<T> values, int Function(T) score) {
  final ranked = [
    for (final (i, value) in values.indexed)
      (value: value, score: score(value), position: i),
  ];
  ranked.sort((a, b) {
    final relevance = b.score.compareTo(a.score);
    return relevance != 0 ? relevance : a.position.compareTo(b.position);
  });
  values
    ..clear()
    ..addAll(ranked.map((entry) => entry.value));
}
