import '../../core/models.dart';

class RestaurantPhoto {
  const RestaurantPhoto({
    required this.key,
    required this.path,
    required this.name,
    required this.note,
    required this.date,
    this.price,
    this.isEnvironment = false,
  });
  final String key;
  final String path;
  final String name;
  final String note;
  final DateTime? date;
  final double? price;
  final bool isEnvironment;
}

List<RestaurantPhoto> restaurantGallery(Restaurant restaurant) {
  final orders = <String, int>{};
  final foods = <({Visit visit, VisitDish dish, int index})>[];
  for (final visit in restaurant.records) {
    for (var i = 0; i < visit.items.length; i++) {
      final dish = visit.items[i];
      foods.add((visit: visit, dish: dish, index: i));
      orders.update(dish.name, (v) => v + 1, ifAbsent: () => 1);
    }
  }
  int weight(VisitDish dish) {
    final note = dish.note;
    final good =
        RegExp(r'^(?!不).*(好|爱|喜欢|推荐|棒|赞|最佳).*$').hasMatch(note) ||
        ['必点', '还不错', 'yyds'].any(note.contains);
    final okay = note.contains('还行') || note.contains('还可以');
    return 100 +
        (good
            ? 30
            : okay
            ? 9
            : note.isNotEmpty
            ? 3
            : 0) +
        ((orders[dish.name] ?? 0) - 1) * 10 +
        (dish.imagePaths.isNotEmpty ? 6 : 0);
  }

  foods.sort((a, b) {
    final order = weight(b.dish).compareTo(weight(a.dish));
    if (order != 0) return order;
    final date = b.visit.date.compareTo(a.visit.date);
    return date != 0 ? date : a.index.compareTo(b.index);
  });
  final visits = [...restaurant.records]
    ..sort((a, b) => b.date.compareTo(a.date));
  final result = <RestaurantPhoto>[
    for (final item in foods)
      for (var i = 0; i < item.dish.imagePaths.length; i++)
        RestaurantPhoto(
          key: '${item.visit.id}:${item.index}:$i',
          path: item.dish.imagePaths[i],
          name: item.dish.name,
          note: item.dish.note,
          date: item.visit.date,
          price: item.dish.price,
        ),
    for (final visit in visits)
      for (var i = 0; i < visit.imagePaths.length; i++)
        RestaurantPhoto(
          key: '${visit.id}:environment:$i',
          path: visit.imagePaths[i],
          name: '用餐环境',
          isEnvironment: true,
          note: '',
          date: visit.date,
        ),
  ];
  return result;
}

String localAddressText(String value) => value.replaceFirst(
  RegExp(
    r'^(?:(?:(?![市区县])[一-鿿]){2,}?(?:省|自治区|特别行政区)\s*)?(?:(?:(?![区县])[一-鿿]){2,}?市\s*)?',
  ),
  '',
);
String restaurantDisplayAddress(
  Restaurant restaurant, {
  RestaurantAddress? address,
}) {
  if (address != null || restaurant.addressEntries.isNotEmpty) {
    final a = address ?? restaurant.addressEntries.first;
    return [
      a.county,
      a.detail,
    ].map(localAddressText).where((v) => v.isNotEmpty).join(' ');
  }
  return restaurant.addresses.isEmpty
      ? '地址待补充'
      : localAddressText(restaurant.addresses.first);
}

String restaurantDetailAddress(
  Restaurant restaurant,
  RestaurantAddress address, {
  required String? currentCity,
}) {
  if (address.city.isEmpty) return address.fullAddress;
  final local = restaurantDisplayAddress(restaurant, address: address);
  return address.city == currentCity ? local : '${address.city} $local';
}
