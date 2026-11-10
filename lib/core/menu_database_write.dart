part of 'menu_database.dart';

List<_TableRows> _tables(
  MenuData data, {
  MenuWriteScope scope = MenuWriteScope.all,
  int? visitPosition,
  bool validateVisitCover = false,
}) {
  if (scope.visitId != null) {
    return _visitTables(data, scope, visitPosition, validateVisitCover);
  }
  final recipes = data.recipes
      .where((r) => scope.allRecipes || scope.recipes.contains(r.id))
      .toList();
  final restaurants = data.restaurants
      .where((r) => scope.allRestaurants || scope.restaurants.contains(r.id))
      .toList();
  for (final restaurant in restaurants) {
    if (restaurant.coverDishId != null &&
        !restaurant.records.any(
          (visit) => visit.items.any(
            (dish) =>
                dish.dishId == restaurant.coverDishId &&
                dish.isDish &&
                dish.imagePaths.isNotEmpty,
          ),
        )) {
      restaurant.coverDishId = null;
    }
  }
  void assignPositions(Map<String, int> positions, Iterable<String> ids) {
    var next = positions.values.fold(-1, (a, b) => a > b ? a : b) + 1;
    for (final id in ids) {
      if (!positions.containsKey(id)) positions[id] = next++;
    }
  }

  assignPositions(data.recipePositions, recipes.map((r) => r.id));
  assignPositions(data.restaurantPositions, restaurants.map((r) => r.id));
  final tags = {...data.recipeTags, for (final r in data.recipes) ...r.tags};
  final categories = {
    ...data.restaurantCategories,
    for (final r in data.restaurants) ...r.categories,
  };
  for (final tag in tags) {
    data.recipeTagIds.putIfAbsent(tag, newId);
  }
  for (final category in categories) {
    data.restaurantCategoryIds.putIfAbsent(category, newId);
  }
  final rules = {'literal': data.tagRules, 'pattern': data.patternTagRules};
  return [
    _TableRows(
      'recipes',
      ['id'],
      [
        for (final r in recipes)
          {
            'id': r.id,
            'position': data.recipePositions[r.id],
            'name': r.name,
            'note': r.note,
            'hidden_rounds': r.hiddenRounds,
            'created_at': r.createdAt.toIso8601String(),
          },
      ],
    ),
    _TableRows(
      'restaurants',
      ['id'],
      [
        for (final r in restaurants)
          {
            'id': r.id,
            'position': data.restaurantPositions[r.id],
            'name': r.name,
            'note': r.note,
            'link': r.link,
            'addresses': jsonEncode(r.addresses),
            'cover_dish_id': r.coverDishId,
          },
      ],
    ),
    _TableRows(
      'restaurant_addresses',
      ['restaurant_id', 'id'],
      [
        for (final r in restaurants)
          for (final (i, a) in r.addressEntries.indexed)
            {
              'restaurant_id': r.id,
              'id': a.id,
              'position': i,
              'province': a.province,
              'city': a.city,
              'county': a.county,
              'detail': a.detail,
              'latitude': a.location?.latitude,
              'longitude': a.location?.longitude,
            },
      ],
    ),
    _TableRows(
      'menu_settings',
      ['id'],
      [
        {'id': 1, 'payload': jsonEncode(_settings(data))},
      ],
    ),
    ..._restaurantRows(restaurants),
    _TableRows(
      'recipe_tags',
      ['id'],
      [
        for (final (i, tag) in tags.indexed)
          {
            'id': data.recipeTagIds[tag],
            'name': tag,
            'position': i,
            'listed': data.recipeTags.contains(tag) ? 1 : 0,
          },
      ],
    ),
    _TableRows(
      'restaurant_categories',
      ['id'],
      [
        for (final (i, name) in categories.indexed)
          {
            'id': data.restaurantCategoryIds[name],
            'name': name,
            'position': i,
            'listed': data.restaurantCategories.contains(name) ? 1 : 0,
          },
      ],
    ),
    _TableRows(
      'restaurant_category_links',
      ['restaurant_id', 'position'],
      [
        for (final r in restaurants)
          for (final (i, category) in r.categories.toSet().indexed)
            {
              'restaurant_id': r.id,
              'position': i,
              'category_id': data.restaurantCategoryIds[category],
            },
      ],
    ),
    _TableRows(
      'recipe_tag_links',
      ['recipe_id', 'position'],
      [
        for (final r in recipes)
          for (final (i, tag) in r.tags.indexed)
            {
              'recipe_id': r.id,
              'position': i,
              'tag_id': data.recipeTagIds[tag],
            },
      ],
    ),
    _TableRows(
      'favorites',
      ['target_type', 'target_id'],
      [
        for (final r in recipes)
          if (r.favorite) {'target_type': 'recipe', 'target_id': r.id},
        for (final r in restaurants)
          if (r.favorite) {'target_type': 'restaurant', 'target_id': r.id},
      ],
    ),
    for (final entry in {
      'to_cook': data.toCook,
      'to_eat': data.toEat,
      'dislikes': data.dislikes,
    }.entries)
      _TableRows(
        entry.key,
        ['position'],
        [
          for (final (i, name) in entry.value.indexed)
            {'position': i, 'name': name},
        ],
      ),
    _TableRows(
      'auto_tag_rules',
      ['mode', 'rule_key'],
      [
        for (final mode in rules.entries)
          for (final (i, rule) in mode.value.entries.indexed)
            {'mode': mode.key, 'rule_key': rule.key, 'position': i},
      ],
    ),
    _TableRows(
      'auto_tag_rule_values',
      ['mode', 'rule_key', 'position'],
      [
        for (final mode in rules.entries)
          for (final rule in mode.value.entries)
            for (final (i, value) in rule.value.indexed)
              {
                'mode': mode.key,
                'rule_key': rule.key,
                'position': i,
                'value': value,
              },
      ],
    ),
    _TableRows(
      'search_history',
      ['search_type', 'position'],
      [
        for (final entry in {
          'recipe': data.recipeSearchHistory,
          'restaurant': data.restaurantSearchHistory,
        }.entries)
          for (final (i, keyword) in entry.value.indexed)
            {'search_type': entry.key, 'position': i, 'keyword': keyword},
      ],
    ),
    _TableRows(
      'images',
      ['kind', 'restaurant_id', 'owner_id', 'item_position', 'position'],
      [
        ..._imageRows('legacy', '', '', data.legacyImagePaths),
        if (data.recipeDraft != null)
          ..._imageRows('draft', '', '', data.recipeDraft!.imagePaths),
        for (final r in recipes)
          ..._imageRows('recipe', '', r.id, r.imagePaths),
        for (final r in restaurants) ...[
          for (final visit in r.records) ...[
            ..._imageRows('visit', r.id, visit.id, visit.imagePaths),
            for (final (i, item) in visit.items.indexed)
              ..._imageRows('item', r.id, visit.id, item.imagePaths, i),
          ],
        ],
      ],
    ),
  ];
}

List<Map<String, Object?>> _imageRows(
  String kind,
  String restaurant,
  String owner,
  List<String> paths, [
  int item = -1,
]) => [
  for (final (i, path) in paths.indexed)
    {
      'kind': kind,
      'restaurant_id': restaurant,
      'owner_id': owner,
      'item_position': item,
      'position': i,
      'path': path,
    },
];

Map<String, dynamic> _settings(MenuData data) => {
  'version': 11,
  'note': data.note,
  'themeMode': data.themeMode,
  'autoTag': data.autoTag,
  'selectedMenu': data.selectedMenu,
  'recipeDraft': (data.recipeDraft?.toJson()?..remove('imagePaths')),
  'recipeDraftSourceId': data.recipeDraftSourceId,
  'recipeTagSort': data.recipeTagSort,
};
