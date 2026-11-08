import 'models.dart';
import 'visit_coupon_migration.dart';

Map<String, dynamic> upgradeMenuV5(Map<String, dynamic> source) {
  for (final restaurant in source['restaurants'] as List) {
    for (final visit in restaurant['records'] as List) {
      for (final coupon in visit['coupons'] as List) {
        coupon['quantity'] = 1;
      }
    }
  }
  return {...source, 'version': 6};
}

Map<String, dynamic> upgradeMenuV4(Map<String, dynamic> source) {
  for (final restaurant in source['restaurants'] as List) {
    for (final visit in restaurant['records'] as List) {
      visit['packages'] = <Map<String, dynamic>>[];
      for (final item in visit['items'] as List) {
        item['packageId'] = null;
      }
    }
  }
  return {...source, 'version': 5};
}

Map<String, dynamic> upgradeMenuV3(Map<String, dynamic> source) {
  for (final restaurant in source['restaurants'] as List) {
    for (final visit in restaurant['records'] as List) {
      final extracted = extractVisitCoupons(visit['note'] as String);
      visit['coupons'] = extracted.coupons.map((c) => c.toJson()).toList();
      visit['note'] = extracted.note;
      if (extracted.coupons.isNotEmpty) {
        final bill = VisitBill(
          (visit['items'] as List).fold(
            0.0,
            (sum, item) =>
                sum + (item['price'] as num) * (item['quantity'] as int),
          ),
          extracted.coupons,
        );
        if ((bill.total * 100).round() !=
            ((visit['totalCost'] as num) * 100).round()) {
          visit['autoCost'] = false;
        }
      }
    }
  }
  return {...source, 'version': 4};
}

Map<String, dynamic> upgradeMenuV2(Map<String, dynamic> source) => {
  ...source,
  'version': 3,
  'restaurantCategories': {
    for (final raw in source['restaurants'] as List)
      if ((raw as Map<String, dynamic>)['category'] != '')
        raw['category'] as String,
  }.toList(),
};

// Upgrade the first Flutter snapshot explicitly. Later schemas remain strict.
Map<String, dynamic> upgradeMenuV1(Map<String, dynamic> source) {
  final upgradedAt = DateTime.now().toIso8601String();
  final tags = <String>{};
  for (final raw in source['recipes'] as List) {
    final recipe = raw as Map<String, dynamic>;
    recipe['createdAt'] = upgradedAt;
    tags.addAll(List<String>.from(recipe['tags'] as List));
  }
  for (final raw in source['restaurants'] as List) {
    final restaurant = raw as Map<String, dynamic>;
    restaurant['addressEntries'] = [
      for (final address in restaurant['addresses'] as List)
        RestaurantAddress(id: newId(), detail: address as String).toJson(),
    ];
    for (final rawVisit in restaurant['records'] as List) {
      final visit = rawVisit as Map<String, dynamic>;
      visit.addAll({
        'addressId': '',
        'address': '',
        'autoCost': false,
        'items': [
          for (final name in visit['dishes'] as List)
            VisitDish(dishId: '', name: name as String).toJson(),
        ],
      });
    }
  }
  return {
    ...source,
    'version': 2,
    'recipeDraft': null,
    'recipeDraftSourceId': null,
    'legacyImagePaths': <String>[],
    'recipeTags': tags.toList(),
    'recipeSearchHistory': <String>[],
    'restaurantSearchHistory': <String>[],
    'recipeTagSort': 'default',
    'patternTagRules': <String, dynamic>{},
  };
}
