part of 'menu_database.dart';

const _restaurantCategoryLinksSchema =
    '''CREATE TABLE restaurant_category_links (
 restaurant_id TEXT NOT NULL, position INTEGER NOT NULL, category_id TEXT NOT NULL,
 PRIMARY KEY (restaurant_id,position))''';

Future<void> _upgradeRestaurantTags(DatabaseExecutor db) async {
  final results = await Future.wait([
    db.query('restaurant_categories', orderBy: 'position'),
    db.query('restaurants', columns: ['id', 'name', 'category_id']),
  ]);
  final categories = results[0];
  final namesById = {
    for (final category in categories)
      category['id'] as String: category['name'] as String,
  };
  final idsByName = {
    for (final category in categories)
      category['name'] as String: category['id'] as String,
  };
  await db.execute(_restaurantCategoryLinksSchema);
  final batch = db.batch();
  var position =
      categories.fold<int>(
        -1,
        (previous, row) => (row['position'] as int) > previous
            ? row['position'] as int
            : previous,
      ) +
      1;
  final visibility = {
    for (final category in categories)
      category['name'] as String: category['listed'] as int,
  };
  void addCatalogPath(String tag, int listed) {
    for (final path in tagPathPrefixes(tag)) {
      if (!idsByName.containsKey(path)) {
        final id = newId();
        idsByName[path] = id;
        visibility[path] = listed;
        batch.insert('restaurant_categories', {
          'id': id,
          'name': path,
          'position': position++,
          'listed': listed,
        });
      } else if (listed == 1 && visibility[path] == 0) {
        visibility[path] = 1;
        batch.update(
          'restaurant_categories',
          {'listed': 1},
          where: 'id = ?',
          whereArgs: [idsByName[path]],
        );
      }
    }
  }

  for (final category in categories) {
    final name = category['name'] as String;
    for (final tag in restaurantCategoryTagChanges[name] ?? [name]) {
      addCatalogPath(tag, category['listed'] as int);
    }
  }
  for (final restaurant in results[1]) {
    final oldId = restaurant['category_id'] as String?;
    final tags = upgradedRestaurantTags(
      restaurant['name'] as String,
      oldId == null ? [] : [namesById[oldId]!],
    );
    for (final (index, tag) in tags.indexed) {
      addCatalogPath(tag, 1);
      batch.insert('restaurant_category_links', {
        'restaurant_id': restaurant['id'],
        'position': index,
        'category_id': idsByName[tag],
      });
    }
  }
  for (final oldName in restaurantCategoryTagChanges.keys) {
    batch.delete(
      'restaurant_categories',
      where: 'name = ?',
      whereArgs: [oldName],
    );
  }
  await batch.commit(noResult: true);
  await db.execute('DROP INDEX restaurants_category');
  await db.execute('ALTER TABLE restaurants DROP COLUMN category_id');
  await db.execute(
    'CREATE INDEX restaurant_category_links_category ON restaurant_category_links (category_id)',
  );
  final row = (await db.query('menu_settings')).single;
  final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
  payload['version'] = 11;
  await db.update('menu_settings', {
    'payload': jsonEncode(payload),
  }, where: 'id = 1');
}
