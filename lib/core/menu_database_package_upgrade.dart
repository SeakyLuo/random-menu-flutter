part of 'menu_database.dart';

const _packageSchema = '''CREATE TABLE restaurant_visit_packages (
 restaurant_id TEXT NOT NULL, visit_id TEXT NOT NULL, id TEXT NOT NULL,
 position INTEGER NOT NULL, name TEXT NOT NULL CHECK (length(trim(name)) > 0),
 total_price REAL NOT NULL CHECK (total_price >= 0),
 PRIMARY KEY (restaurant_id,visit_id,id))''';

Future<void> _upgradeVisitPackages(DatabaseExecutor db) async {
  await db.execute(_packageSchema);
  await db.execute(
    'ALTER TABLE restaurant_visit_items ADD COLUMN package_id TEXT',
  );
  final settings = await db.query('menu_settings');
  final batch = db.batch();
  for (final row in settings) {
    final payload =
        jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    payload['version'] = 5;
    batch.update(
      'menu_settings',
      {'payload': jsonEncode(payload)},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
  await batch.commit(noResult: true);
}
