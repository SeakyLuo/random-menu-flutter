part of 'menu_database.dart';

const _couponSchema = '''CREATE TABLE restaurant_visit_coupons (
 restaurant_id TEXT NOT NULL, visit_id TEXT NOT NULL, position INTEGER NOT NULL,
 threshold REAL CHECK (threshold IS NULL OR threshold > 0),
 discount REAL NOT NULL CHECK (discount > 0),
 quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity BETWEEN 1 AND 100),
 PRIMARY KEY (restaurant_id,visit_id,position))''';

Future<void> _upgradeVisitCoupons(DatabaseExecutor db) async {
  await db.execute(_couponSchema);
  final results = await Future.wait([
    db.query('restaurant_visits'),
    db.query('restaurant_visit_items'),
    db.query('menu_settings'),
  ]);
  final subtotals = <(String, String), double>{};
  for (final item in results[1]) {
    final key = (item['restaurant_id'] as String, item['visit_id'] as String);
    subtotals[key] =
        (subtotals[key] ?? 0) +
        (item['price'] as num).toDouble() * (item['quantity'] as int);
  }
  final batch = db.batch();
  for (final visit in results[0]) {
    final extracted = extractVisitCoupons(visit['note'] as String);
    if (extracted.coupons.isEmpty) continue;
    final restaurant = visit['restaurant_id'] as String;
    final id = visit['id'] as String;
    final bill = VisitBill(subtotals[(restaurant, id)] ?? 0, extracted.coupons);
    batch.update(
      'restaurant_visits',
      {
        'note': extracted.note,
        'auto_cost':
            visit['auto_cost'] == 1 &&
                (bill.total * 100).round() ==
                    ((visit['total_cost'] as num) * 100).round()
            ? 1
            : 0,
      },
      where: 'restaurant_id = ? AND id = ?',
      whereArgs: [restaurant, id],
    );
    for (final (position, coupon) in extracted.coupons.indexed) {
      batch.insert('restaurant_visit_coupons', {
        'restaurant_id': restaurant,
        'visit_id': id,
        'position': position,
        'threshold': coupon.threshold,
        'discount': coupon.discount,
        'quantity': coupon.quantity,
      });
    }
  }
  for (final row in results[2]) {
    final settings =
        jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    settings['version'] = 4;
    batch.update(
      'menu_settings',
      {'payload': jsonEncode(settings)},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }
  await batch.commit(noResult: true);
}
