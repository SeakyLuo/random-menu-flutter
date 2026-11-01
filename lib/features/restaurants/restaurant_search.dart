import 'dart:math';
import '../../core/models.dart';

int _textScore(String text, String query, [int offset = 0]) {
  if (text.isEmpty) return 0;
  var score = 0;
  if (text == query) {
    score = 100;
  } else if (text.startsWith(query)) {
    score = 95;
  } else if (text.endsWith(query)) {
    score = 90;
  } else if (text.contains(query)) {
    score = 85;
  } else {
    var previous = List.generate(query.length + 1, (i) => i);
    for (var i = 1; i <= text.length; i++) {
      final current = List.filled(query.length + 1, 0)..[0] = i;
      for (var j = 1; j <= query.length; j++) {
        current[j] = min(
          min(previous[j] + 1, current[j - 1] + 1),
          previous[j - 1] + (text[i - 1] == query[j - 1] ? 0 : 1),
        );
      }
      previous = current;
    }
    final ratio = previous.last * 100 ~/ max(text.length, query.length);
    if (ratio <= 60) score = 85 - ratio;
  }
  return max(score + offset, 0);
}

int restaurantSearchScore(Restaurant restaurant, String query) {
  int score(String value, [int offset = 0]) =>
      _textScore(value.toLowerCase(), query.toLowerCase(), offset);
  var total =
      score(restaurant.name) +
      score(restaurant.note, -10) +
      score(restaurant.category, -10);
  for (final address in restaurant.addresses) {
    total += score(address, -15);
  }
  for (final food in restaurant.foods) {
    total += score(food.name, -15) + score(food.note, -20);
  }
  for (final record in restaurant.records) {
    total += score(record.note, -15);
    for (final food in record.items) {
      total += score(food.name, -15) + score(food.note, -20);
    }
  }
  return total;
}
