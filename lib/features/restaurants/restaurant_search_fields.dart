import '../../core/models.dart';
import 'restaurant_dish_summary.dart';
import 'restaurant_filter.dart';
import 'restaurants_page.dart' show orderedRestaurants;

enum RestaurantSearchField { all, restaurants, dishes, reviews }

class RestaurantSearchHit {
  const RestaurantSearchHit(this.restaurant, this.context);
  final Restaurant restaurant;
  final String? context;
}

class RestaurantDishHit {
  const RestaurantDishHit(this.restaurant, this.dish, this.note);
  final Restaurant restaurant;
  final RestaurantDishSummary dish;
  final String? note;
}

class RestaurantReviewHit {
  const RestaurantReviewHit({
    required this.restaurant,
    required this.key,
    required this.text,
    required this.source,
    required this.photos,
    this.visit,
    this.dishName,
  });
  final Restaurant restaurant;
  final String text, source;
  final List<String> photos;
  final Visit? visit;
  final String? dishName;
  final Object key;
}

class RestaurantSearchMatches {
  final restaurants = <RestaurantSearchHit>[];
  final dishes = <RestaurantDishHit>[];
  final reviews = <RestaurantReviewHit>[];

  int count(RestaurantSearchField field) => switch (field) {
    RestaurantSearchField.all =>
      restaurants.length + dishes.length + reviews.length,
    RestaurantSearchField.restaurants => restaurants.length,
    RestaurantSearchField.dishes => dishes.length,
    RestaurantSearchField.reviews => reviews.length,
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
      restaurant.category,
      ...restaurant.addressEntries.map((address) => address.fullAddress),
      ...restaurant.addresses,
      ...restaurant.records.map((visit) => visit.address),
      restaurant.note,
    ];
    final context = fields.where(matches).firstOrNull;
    if (matches(restaurant.name) || context != null) {
      result.restaurants.add(
        RestaurantSearchHit(
          restaurant,
          matches(restaurant.note)
              ? restaurant.note
              : matches(restaurant.name)
              ? null
              : context,
        ),
      );
    }
    for (final dish in restaurantDishSummaries(restaurant)) {
      final notes = [
        if (dish.saved case final saved?) saved.note,
        ...dish.history.map((entry) => entry.dish.note),
      ];
      final note = notes.where(matches).firstOrNull;
      if (matches(dish.name) || note != null) {
        result.dishes.add(RestaurantDishHit(restaurant, dish, note));
      }
    }
    if (matches(restaurant.note)) {
      result.reviews.add(
        RestaurantReviewHit(
          restaurant: restaurant,
          key: (restaurant.id, 'note'),
          text: restaurant.note,
          source: '餐厅备注',
          photos: const [],
        ),
      );
    }
    for (final visit in restaurant.records) {
      if (matches(visit.note)) {
        result.reviews.add(
          RestaurantReviewHit(
            restaurant: restaurant,
            visit: visit,
            key: (restaurant.id, visit.id),
            text: visit.note,
            source: '到店评价',
            photos: {
              ...visit.imagePaths,
              ...visit.items.expand((dish) => dish.imagePaths),
            }.toList(),
          ),
        );
      }
      for (final (index, dish) in visit.items.indexed) {
        if (matches(dish.note)) {
          result.reviews.add(
            RestaurantReviewHit(
              restaurant: restaurant,
              visit: visit,
              dishName: dish.name,
              key: (restaurant.id, visit.id, index),
              text: dish.note,
              source: '菜品评价 · ${dish.name}',
              photos: dish.imagePaths,
            ),
          );
        }
      }
    }
  }
  result.reviews.sort((a, b) {
    if (a.visit == null && b.visit == null) return 0;
    if (a.visit == null) return 1;
    if (b.visit == null) return -1;
    return b.visit!.date.compareTo(a.visit!.date);
  });
  return result;
}
