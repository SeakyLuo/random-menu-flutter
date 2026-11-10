part of 'menu_database.dart';

Future<({MenuData data, int? position, bool coverInVisit})> _readVisit(
  Transaction txn,
  MenuData current,
  MenuWriteScope scope,
) async {
  final restaurantId = scope.restaurants.single;
  final visitId = scope.visitId!;
  final batch = txn.batch();
  batch.query(
    'restaurants',
    columns: ['cover_dish_id'],
    where: 'id = ?',
    whereArgs: [restaurantId],
  );
  batch.query(
    'restaurant_visits',
    where: 'restaurant_id = ? AND id = ?',
    whereArgs: [restaurantId, visitId],
  );
  for (final table in [
    'restaurant_visit_items',
    'restaurant_visit_coupons',
    'restaurant_visit_packages',
    'visit_companions',
  ]) {
    batch.query(
      table,
      where: 'restaurant_id = ? AND visit_id = ?',
      whereArgs: [restaurantId, visitId],
      orderBy: 'position',
    );
  }
  batch.query(
    'images',
    where: 'restaurant_id = ? AND owner_id = ? AND kind IN (?, ?)',
    whereArgs: [restaurantId, visitId, 'visit', 'item'],
    orderBy: 'kind, item_position, position',
  );
  batch.query(
    'restaurant_addresses',
    where: 'restaurant_id = ?',
    whereArgs: [restaurantId],
    orderBy: 'position',
  );
  final results = await batch.commit();
  List<Map<String, Object?>> rows(int index) =>
      List<Map<String, Object?>>.from(results[index] as List);
  final photos = <(String, int), List<String>>{};
  for (final image in rows(6)) {
    (photos[(image['kind'] as String, image['item_position'] as int)] ??= [])
        .add(image['path'] as String);
  }
  final visits = _visitGroups(
    rows(1),
    rows(2),
    rows(5),
    rows(3),
    rows(4),
    (kind, restaurant, owner, [item = -1]) => photos[(kind, item)] ?? [],
  );
  final restaurants = [
    for (final restaurant in current.restaurants)
      if (restaurant.id != restaurantId)
        restaurant
      else
        Restaurant(
          id: restaurant.id,
          name: restaurant.name,
          categories: [...restaurant.categories],
          addresses: restaurant.addresses,
          addressEntries: [
            for (final address in rows(7))
              RestaurantAddress.fromJson({
                'id': address['id'],
                'province': address['province'],
                'city': address['city'],
                'county': address['county'],
                'detail': address['detail'],
                'location': address['latitude'] == null
                    ? null
                    : {
                        'latitude': address['latitude'],
                        'longitude': address['longitude'],
                      },
              }),
          ],
          note: restaurant.note,
          link: restaurant.link,
          favorite: restaurant.favorite,
          coverDishId: rows(0).single['cover_dish_id'] as String?,
          records: _mergeRecords(
            restaurant.records,
            visits[restaurantId] ?? [],
            {visitId},
            (visit) => visit.id,
          ),
        ),
  ];
  final data =
      MenuData(
          recipes: current.recipes,
          restaurants: restaurants,
          toCook: current.toCook,
          toEat: current.toEat,
          dislikes: current.dislikes,
          note: current.note,
          themeMode: current.themeMode,
          autoTag: current.autoTag,
          tagRules: current.tagRules,
          selectedMenu: current.selectedMenu,
          recipeDraft: current.recipeDraft,
          recipeDraftSourceId: current.recipeDraftSourceId,
          legacyImagePaths: current.legacyImagePaths,
          recipeTags: current.recipeTags,
          restaurantCategories: current.restaurantCategories,
          recipeSearchHistory: current.recipeSearchHistory,
          restaurantSearchHistory: current.restaurantSearchHistory,
          recipeTagSort: current.recipeTagSort,
          patternTagRules: current.patternTagRules,
        )
        ..recipePositions = current.recipePositions
        ..restaurantPositions = current.restaurantPositions
        ..recipeTagIds = current.recipeTagIds
        ..restaurantCategoryIds = current.restaurantCategoryIds;
  final cover = rows(0).single['cover_dish_id'];
  return (
    data: data,
    position: rows(1).firstOrNull?['position'] as int?,
    coverInVisit:
        visits[restaurantId]?.single.items.any(
          (dish) => dish.dishId == cover,
        ) ??
        false,
  );
}

List<_TableRows> _visitTables(
  MenuData data,
  MenuWriteScope scope,
  int? position,
  bool validateCover,
) {
  final restaurant = data.restaurants.firstWhere(
    (r) => r.id == scope.restaurants.single,
  );
  final visits = restaurant.records
      .where((visit) => visit.id == scope.visitId)
      .toList();
  final cover = restaurant.coverDishId;
  if (validateCover &&
      cover != null &&
      !visits.any(
        (visit) => visit.items.any(
          (dish) =>
              dish.dishId == cover && dish.isDish && dish.imagePaths.isNotEmpty,
        ),
      )) {
    restaurant.coverDishId = null;
  }
  final result = _restaurantRows([
    Restaurant(id: restaurant.id, name: restaurant.name, records: visits),
  ]);
  for (final table in result) {
    if (table.name == 'restaurant_visits') {
      for (final row in table.rows) {
        row['position'] = position!;
      }
    }
  }
  return [
    _TableRows(
      'restaurants',
      ['id'],
      [
        {'id': restaurant.id, 'cover_dish_id': restaurant.coverDishId},
      ],
    ),
    ...result,
    _TableRows(
      'images',
      ['kind', 'restaurant_id', 'owner_id', 'item_position', 'position'],
      [
        for (final visit in visits) ...[
          ..._imageRows('visit', restaurant.id, visit.id, visit.imagePaths),
          for (final (index, dish) in visit.items.indexed)
            ..._imageRows(
              'item',
              restaurant.id,
              visit.id,
              dish.imagePaths,
              index,
            ),
        ],
      ],
    ),
  ];
}
