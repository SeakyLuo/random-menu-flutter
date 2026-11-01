import 'models.dart';

// Upgrade the first Flutter snapshot explicitly. Later schemas remain strict.
Map<String, dynamic> upgradeMenuV1(Map<String, dynamic> source) {
  final upgradedAt = DateTime.now().toIso8601String();
  final tags = <String>{};
  for (final raw in source['recipes'] as List) {
    final recipe = raw as Map<String, dynamic>;
    recipe['createdAt'] = upgradedAt;
    tags.addAll(List<String>.from(recipe['tags'] as List));
  }
  for (final raw in source['restaurants'] as List) {
    final restaurant = raw as Map<String, dynamic>;
    restaurant['addressEntries'] = [
      for (final address in restaurant['addresses'] as List)
        RestaurantAddress(id: newId(), detail: address as String).toJson(),
    ];
    for (final rawDish in restaurant['foods'] as List) {
      (rawDish as Map<String, dynamic>)['quantity'] = 1;
    }
    for (final rawVisit in restaurant['records'] as List) {
      final visit = rawVisit as Map<String, dynamic>;
      visit.addAll({
        'addressId': '',
        'address': '',
        'autoCost': false,
        'items': [
          for (final name in visit['dishes'] as List)
            VisitDish(dishId: '', name: name as String).toJson(),
        ],
      });
    }
  }
  return {
    ...source,
    'version': 2,
    'recipeDraft': null,
    'recipeDraftSourceId': null,
    'legacyImagePaths': <String>[],
    'recipeTags': tags.toList(),
    'recipeSearchHistory': <String>[],
    'restaurantSearchHistory': <String>[],
    'recipeTagSort': 'default',
    'patternTagRules': <String, dynamic>{},
    'legacyMetadata': <String, dynamic>{},
  };
}
