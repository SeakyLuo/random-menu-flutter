part of 'menu_database.dart';

Future<void> _upgradeDiscountCoupons(DatabaseExecutor db) async {
  await db.execute(
    'ALTER TABLE restaurant_visit_coupons RENAME TO previous_visit_coupons',
  );
  await db.execute(_couponSchema);
  await db.execute('''INSERT INTO restaurant_visit_coupons
    (restaurant_id,visit_id,position,threshold,discount,quantity)
    SELECT restaurant_id,visit_id,position,threshold,discount,quantity
    FROM previous_visit_coupons''');
  await db.execute('DROP TABLE previous_visit_coupons');
  final settings = (await db.query('menu_settings')).single;
  final payload =
      jsonDecode(settings['payload'] as String) as Map<String, dynamic>;
  payload['version'] = 9;
  await db.update('menu_settings', {
    'payload': jsonEncode(payload),
  }, where: 'id = 1');
}
