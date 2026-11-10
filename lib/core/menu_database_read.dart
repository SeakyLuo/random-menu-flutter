part of 'menu_database.dart';

Future<MenuData> _read(
  Transaction txn, {
  MenuWriteScope scope = MenuWriteScope.all,
  MenuData? current,
}) async {
  if (scope.visitId != null) {
    return (await _readVisit(txn, current!, scope)).data;
  }
  final batch = txn.batch();
  final tables = <String>[];
  final rows = <String, List<Map<String, Object?>>>{};
  for (final table in MenuSqlStatement.tables) {
    if (_queueReadTable(batch, table, scope)) {
      tables.add(table);
    } else {
      rows[table] = [];
    }
  }
  // Keep the snapshot transaction while crossing the platform channel once.
  final results = await batch.commit();
  for (var i = 0; i < tables.length; i++) {
    rows[tables[i]] = List<Map<String, Object?>>.from(results[i] as List);
  }
  final settings =
      jsonDecode(rows['menu_settings']!.single['payload'] as String)
          as Map<String, dynamic>;
  final tags = {
    for (final row in rows['recipe_tags']!)
      row['id'] as String: row['name'] as String,
  };
  final categories = {
    for (final row in rows['restaurant_categories']!)
      row['id'] as String: row['name'] as String,
  };
  final photos = <(String, String, String, int), List<String>>{};
  for (final row in rows['images']!) {
    (photos[(
              row['kind'] as String,
              row['restaurant_id'] as String,
              row['owner_id'] as String,
              row['item_position'] as int,
            )] ??=
            [])
        .add(row['path'] as String);
  }
  List<String> images(
    String kind,
    String restaurant,
    String owner, [
    int item = -1,
  ]) => photos[(kind, restaurant, owner, item)] ?? [];
  final favorites = {
    for (final row in rows['favorites']!)
      (row['target_type'], row['target_id']),
  };
  final links = <String, List<String>>{};
  for (final row in rows['recipe_tag_links']!) {
    (links[row['recipe_id'] as String] ??= []).add(tags[row['tag_id']]!);
  }
  final restaurantTags = <String, List<String>>{};
  for (final row in rows['restaurant_category_links']!) {
    (restaurantTags[row['restaurant_id'] as String] ??= []).add(categories[row['category_id']]!);
  }
  final recipes = [
    for (final row in rows['recipes']!)
      Recipe(
        id: row['id'] as String,
        name: row['name'] as String,
        note: row['note'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        hiddenRounds: row['hidden_rounds'] as int,
        tags: links[row['id']] ?? [],
        imagePaths: images('recipe', '', row['id'] as String),
        favorite: favorites.contains(('recipe', row['id'])),
      ),
  ];
  final branches = <String, List<RestaurantAddress>>{};
  for (final row in rows['restaurant_addresses']!) {
    (branches[row['restaurant_id'] as String] ??= []).add(
      RestaurantAddress.fromJson({
        'id': row['id'],
        'province': row['province'],
        'city': row['city'],
        'county': row['county'],
        'detail': row['detail'],
        'location': row['latitude'] == null
            ? null
            : {'latitude': row['latitude'], 'longitude': row['longitude']},
      }),
    );
  }
  final visits = _visitGroups(
    rows['restaurant_visits']!,
    rows['restaurant_visit_items']!,
    rows['visit_companions']!,
    rows['restaurant_visit_coupons']!,
    rows['restaurant_visit_packages']!,
    images,
  );
  final restaurants = [
    for (final row in rows['restaurants']!)
      Restaurant(
        id: row['id'] as String,
        name: row['name'] as String,
        note: row['note'] as String,
        link: row['link'] as String,
        categories: restaurantTags[row['id']] ?? [],
        addresses: List<String>.from(
          jsonDecode(row['addresses'] as String) as List,
        ),
        addressEntries: branches[row['id']] ?? [],
        records: visits[row['id']] ?? [],
        favorite: favorites.contains(('restaurant', row['id'])),
        coverDishId: row['cover_dish_id'] as String?,
      ),
  ];
  final values = <(String, String), List<String>>{};
  for (final row in rows['auto_tag_rule_values']!) {
    (values[(row['mode'] as String, row['rule_key'] as String)] ??= []).add(
      row['value'] as String,
    );
  }
  final rules = <String, Map<String, List<String>>>{
    'literal': {},
    'pattern': {},
  };
  for (final row in rows['auto_tag_rules']!) {
    final mode = row['mode'] as String, key = row['rule_key'] as String;
    rules[mode]![key] = values[(mode, key)] ?? [];
  }
  final draft = settings['recipeDraft'] as Map<String, dynamic>?;
  if (draft != null) draft['imagePaths'] = images('draft', '', '');
  final data = MenuData.fromJson({
    ...settings,
    'recipes': <Map<String, dynamic>>[],
    'restaurants': <Map<String, dynamic>>[],
    'recipeTags': [
      for (final row in rows['recipe_tags']!)
        if (row['listed'] == 1) row['name'],
    ],
    'restaurantCategories': [
      for (final row in rows['restaurant_categories']!)
        if (row['listed'] == 1) row['name'],
    ],
    'legacyImagePaths': images('legacy', '', ''),
    'recipeSearchHistory': [
      for (final row in rows['search_history']!)
        if (row['search_type'] == 'recipe') row['keyword'],
    ],
    'restaurantSearchHistory': [
      for (final row in rows['search_history']!)
        if (row['search_type'] == 'restaurant') row['keyword'],
    ],
    'toCook': [for (final row in rows['to_cook']!) row['name']],
    'toEat': [for (final row in rows['to_eat']!) row['name']],
    'dislikes': [for (final row in rows['dislikes']!) row['name']],
    'tagRules': rules['literal'],
    'patternTagRules': rules['pattern'],
  });
  data.recipePositions = {
    ...?current?.recipePositions,
    for (final row in rows['recipes']!)
      row['id'] as String: row['position'] as int,
  };
  data.restaurantPositions = {
    ...?current?.restaurantPositions,
    for (final row in rows['restaurants']!)
      row['id'] as String: row['position'] as int,
  };
  data.recipeTagIds = {
    for (final row in rows['recipe_tags']!)
      row['name'] as String: row['id'] as String,
  };
  data.restaurantCategoryIds = {
    for (final row in rows['restaurant_categories']!)
      row['name'] as String: row['id'] as String,
  };
  data.recipes = scope.allRecipes
      ? recipes
      : _mergeRecords(current!.recipes, recipes, scope.recipes, (r) => r.id);
  data.restaurants = scope.allRestaurants
      ? restaurants
      : _mergeRecords(
          current!.restaurants,
          restaurants,
          scope.restaurants,
          (r) => r.id,
        );
  return data;
}

List<T> _mergeRecords<T>(
  List<T> current,
  List<T> fresh,
  Set<String> ids,
  String Function(T) id,
) {
  final updated = {for (final item in fresh) id(item): item};
  return [
    for (final item in current)
      if (!ids.contains(id(item)))
        item
      else if (updated.containsKey(id(item)))
        updated.remove(id(item))!,
    ...updated.values,
  ];
}

bool _queueReadTable(Batch batch, String table, MenuWriteScope scope) {
  final order = switch (table) {
    'recipes' ||
    'restaurants' ||
    'recipe_tags' ||
    'restaurant_categories' ||
    'to_cook' ||
    'to_eat' ||
    'dislikes' => 'position',
    'auto_tag_rules' => 'mode, position',
    'auto_tag_rule_values' => 'mode, rule_key, position',
    'recipe_tag_links' => 'recipe_id, position',
    'restaurant_category_links' => 'restaurant_id, position',
    'restaurant_addresses' || 'restaurant_visits' => 'restaurant_id, position',
    'restaurant_visit_items' ||
    'restaurant_visit_coupons' ||
    'restaurant_visit_packages' ||
    'visit_companions' => 'restaurant_id, visit_id, position',
    'search_history' => 'search_type, position',
    'images' => 'kind, restaurant_id, owner_id, item_position, position',
    _ => null,
  };
  final filter = _rowFilter(table, scope);
  if (filter.$1 == '0') return false;
  batch.query(table, where: filter.$1, whereArgs: filter.$2, orderBy: order);
  return true;
}

(String?, List<Object?>) _rowFilter(String table, MenuWriteScope scope) {
  (String?, List<Object?>) ids(String column, bool all, Set<String> values) =>
      all
      ? (null, [])
      : values.isEmpty
      ? ('0', [])
      : (
          '$column IN (${List.filled(values.length, '?').join(',')})',
          values.toList(),
        );
  if (table == 'recipes' || table == 'recipe_tag_links') {
    return ids(
      table == 'recipes' ? 'id' : 'recipe_id',
      scope.allRecipes,
      scope.recipes,
    );
  }
  if ([
    'restaurants',
    'restaurant_addresses',
    'restaurant_category_links',
    'restaurant_visits',
    'restaurant_visit_items',
    'restaurant_visit_coupons',
    'restaurant_visit_packages',
    'visit_companions',
  ].contains(table)) {
    return ids(
      table == 'restaurants' ? 'id' : 'restaurant_id',
      scope.allRestaurants,
      scope.restaurants,
    );
  }
  if (table == 'images' || table == 'favorites') {
    final recipe = ids(
      table == 'images' ? 'owner_id' : 'target_id',
      scope.allRecipes,
      scope.recipes,
    );
    final restaurant = ids(
      table == 'images' ? 'restaurant_id' : 'target_id',
      scope.allRestaurants,
      scope.restaurants,
    );
    final type = table == 'images' ? 'kind' : 'target_type';
    return (
      '${table == 'images' ? "kind IN ('draft','legacy') OR " : ''}($type = \'recipe\' AND (${recipe.$1 ?? '1'})) OR ($type ${table == 'images' ? "IN ('dish','visit','item')" : "= 'restaurant'"} AND (${restaurant.$1 ?? '1'}))',
      [...recipe.$2, ...restaurant.$2],
    );
  }
  return (null, []);
}
