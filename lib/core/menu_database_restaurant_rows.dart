part of 'menu_database.dart';

typedef _Images = List<String> Function(String, String, String, [int]);

Map<String, List<RestaurantDish>> _dishGroups(
  List<Map<String, Object?>> rows,
  _Images images,
) {
  final result = <String, List<RestaurantDish>>{};
  for (final row in rows) {
    final restaurant = row['restaurant_id'] as String, id = row['id'] as String;
    (result[restaurant] ??= []).add(
      RestaurantDish(
        id: id,
        name: row['name'] as String,
        price: (row['price'] as num).toDouble(),
        quantity: row['quantity'] as int,
        note: row['note'] as String,
        imagePaths: images('dish', restaurant, id),
      ),
    );
  }
  return result;
}

Map<String, List<Visit>> _visitGroups(
  List<Map<String, Object?>> visits,
  List<Map<String, Object?>> items,
  List<Map<String, Object?>> people,
  List<Map<String, Object?>> couponRows,
  _Images images,
) {
  final coupons = <(String, String), List<VisitCoupon>>{};
  for (final row in couponRows) {
    (coupons[(row['restaurant_id'] as String, row['visit_id'] as String)] ??=
            [])
        .add(
          VisitCoupon(
            threshold: (row['threshold'] as num?)?.toDouble(),
            discount: (row['discount'] as num).toDouble(),
          ),
        );
  }
  final companions = <(String, String), List<String>>{};
  for (final row in people) {
    (companions[(row['restaurant_id'] as String, row['visit_id'] as String)] ??=
            [])
        .add(row['name'] as String);
  }
  final grouped = <(String, String), List<VisitDish>>{};
  for (final row in items) {
    final restaurant = row['restaurant_id'] as String,
        visit = row['visit_id'] as String;
    (grouped[(restaurant, visit)] ??= []).add(
      VisitDish(
        dishId: row['dish_id'] as String,
        name: row['name'] as String,
        price: (row['price'] as num).toDouble(),
        quantity: row['quantity'] as int,
        note: row['note'] as String,
        imagePaths: images('item', restaurant, visit, row['position'] as int),
      ),
    );
  }
  final result = <String, List<Visit>>{};
  for (final row in visits) {
    final restaurant = row['restaurant_id'] as String, id = row['id'] as String;
    (result[restaurant] ??= []).add(
      Visit(
        id: id,
        date: DateTime.parse(row['date'] as String),
        totalCost: (row['total_cost'] as num).toDouble(),
        addressId: row['address_id'] as String,
        address: row['address'] as String,
        autoCost: row['auto_cost'] == 1,
        coupons: coupons[(restaurant, id)] ?? [],
        note: row['note'] as String,
        dishes: List<String>.from(jsonDecode(row['dishes'] as String) as List),
        companions: companions[(restaurant, id)] ?? [],
        items: grouped[(restaurant, id)] ?? [],
        imagePaths: images('visit', restaurant, id),
      ),
    );
  }
  return result;
}

List<_TableRows> _restaurantRows(List<Restaurant> restaurants) => [
  _TableRows(
    'restaurant_visit_coupons',
    ['restaurant_id', 'visit_id', 'position'],
    [
      for (final restaurant in restaurants)
        for (final visit in restaurant.records)
          for (final (position, coupon) in visit.coupons.indexed)
            {
              'restaurant_id': restaurant.id,
              'visit_id': visit.id,
              'position': position,
              'threshold': coupon.threshold,
              'discount': coupon.discount,
            },
    ],
  ),
  _TableRows(
    'restaurant_dishes',
    ['restaurant_id', 'id'],
    [
      for (final r in restaurants)
        for (final (i, d) in r.foods.indexed)
          {
            'restaurant_id': r.id,
            'id': d.id,
            'position': i,
            'name': d.name,
            'price': d.price,
            'quantity': d.quantity,
            'note': d.note,
          },
    ],
  ),
  _TableRows(
    'restaurant_visits',
    ['restaurant_id', 'id'],
    [
      for (final r in restaurants)
        for (final (i, v) in r.records.indexed)
          {
            'restaurant_id': r.id,
            'id': v.id,
            'position': i,
            'date': v.date.toIso8601String(),
            'total_cost': v.totalCost,
            'address_id': v.addressId,
            'address': v.address,
            'auto_cost': v.autoCost ? 1 : 0,
            'note': v.note,
            'dishes': jsonEncode(v.dishes),
          },
    ],
  ),
  _TableRows(
    'restaurant_visit_items',
    ['restaurant_id', 'visit_id', 'position'],
    [
      for (final r in restaurants)
        for (final v in r.records)
          for (final (i, d) in v.items.indexed)
            {
              'restaurant_id': r.id,
              'visit_id': v.id,
              'position': i,
              'dish_id': d.dishId,
              'name': d.name,
              'price': d.price,
              'quantity': d.quantity,
              'note': d.note,
            },
    ],
  ),
  _TableRows(
    'visit_companions',
    ['restaurant_id', 'visit_id', 'position'],
    [
      for (final r in restaurants)
        for (final v in r.records)
          for (final (i, name) in v.companions.indexed)
            {
              'restaurant_id': r.id,
              'visit_id': v.id,
              'position': i,
              'name': name,
            },
    ],
  ),
];
