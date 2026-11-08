part of 'menu_database.dart';

Future<void> _upgradeCouponQuantities(
  DatabaseExecutor db,
  int oldVersion,
) async {
  if (oldVersion >= 2) {
    await db.execute(
      'ALTER TABLE restaurant_visit_coupons ADD COLUMN quantity '
      'INTEGER NOT NULL DEFAULT 1 CHECK (quantity BETWEEN 1 AND 100)',
    );
  }
  final settings = await db.query('menu_settings');
  final batch = db.batch();
  for (final row in settings) {
    final payload =
        jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    payload['version'] = 6;
    batch.update(
      'menu_settings',
      {'payload': jsonEncode(payload)},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
  await batch.commit(noResult: true);
}
