part of 'menu_database.dart';

Future<void> _upgradeDishIdentities(DatabaseExecutor db) async {
  final rows = await db.query(
    'restaurant_visit_items',
    columns: ['restaurant_id', 'visit_id', 'position', 'dish_id'],
    orderBy: 'restaurant_id, visit_id, position',
  );
  final ids = rows.map((row) => row['dish_id'] as String).toList();
  final upgraded = upgradedDishIds(ids);
  final changed = <String, Set<String>>{};
  final batch = db.batch();
  for (var i = 0; i < rows.length; i++) {
    if (ids[i] == upgraded[i]) continue;
    final row = rows[i];
    (changed[row['restaurant_id'] as String] ??= {}).add(ids[i]);
    batch.update(
      'restaurant_visit_items',
      {'dish_id': upgraded[i]},
      where: 'restaurant_id = ? AND visit_id = ? AND position = ?',
      whereArgs: [row['restaurant_id'], row['visit_id'], row['position']],
    );
  }
  for (final entry in changed.entries) {
    for (final id in entry.value) {
      batch.update(
        'restaurants',
        {'cover_dish_id': null},
        where: 'id = ? AND cover_dish_id = ?',
        whereArgs: [entry.key, id],
      );
    }
  }
  final settings = (await db.query('menu_settings')).single;
  final payload =
      jsonDecode(settings['payload'] as String) as Map<String, dynamic>;
  payload['version'] = 8;
  batch.update('menu_settings', {
    'payload': jsonEncode(payload),
  }, where: 'id = 1');
  await batch.commit(noResult: true);
}
