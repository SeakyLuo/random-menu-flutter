import '../../core/models.dart';
import '../../core/visit_coupon_migration.dart';
import 'legacy_reader.dart';

List<Restaurant> parseLegacyRestaurants(
  List<dynamic> source,
  LegacyFiles files,
) => source.map((raw) => _LegacyRestaurant(files).parse(raw)).toList();

class _LegacyRestaurant {
  _LegacyRestaurant(this.files);
  final LegacyFiles files;
  late int restaurantId;
  final dishes = <int, _Dish>{};
  final visitIds = <int>{};

  Restaurant parse(Object? raw) {
    final restaurant = LegacyObject(raw, {
      'id',
      'name',
      'addressList',
      'foodType',
      'averageCost',
      'comment',
      'link',
      'favorite',
      'consumeCount',
      'records',
      'foods',
    });
    restaurantId = restaurant.integer('id');
    if (restaurantId <= 0) restaurant.fail();
    restaurant.number('averageCost');
    restaurant.integer('consumeCount');
    final addresses = restaurant.list('addressList').map(_address).toList();
    if (addresses.map((address) => address.id).toSet().length !=
        addresses.length) {
      restaurant.fail();
    }
    final records = restaurant
        .list('records')
        .map((raw) => _visit(raw, addresses))
        .toList();
    for (final rawDish in restaurant.list('foods', omitted: true)) {
      _dish(rawDish);
    }
    final home = dishes.values.where((dish) => dish.orderInHome >= 0).toList()
      ..sort((a, b) => a.orderInHome.compareTo(b.orderInHome));
    var category = '';
    if (restaurant.has('foodType')) {
      final type = LegacyObject(restaurant.values['foodType'], {'id', 'name'});
      type.integer('id');
      category = type.text('name', required: true);
    }
    return Restaurant(
      id: 'android-restaurant-$restaurantId',
      name: restaurant.text('name', required: true),
      category: category,
      addresses: addresses.map((address) => address.fullAddress).toList(),
      addressEntries: addresses,
      note: restaurant.text('comment'),
      link: restaurant.text('link'),
      favorite: restaurant.flag('favorite'),
      records: records,
      foods: home
          .map(
            (dish) => RestaurantDish(
              id: dish.id,
              name: dish.name,
              price: dish.price,
              quantity: dish.quantity,
              note: dish.note,
              imagePaths: dish.images,
            ),
          )
          .toList(),
    );
  }

  RestaurantAddress _address(Object? raw) {
    final address = LegacyObject(raw, {
      'id',
      'province',
      'city',
      'county',
      'address',
    });
    final id = address.integer('id');
    if (id <= 0) address.fail();
    return RestaurantAddress(
      id: 'android-address-$id',
      province: address.text('province'),
      city: address.text('city'),
      county: address.text('county'),
      detail: address.text('address'),
    );
  }

  Visit _visit(Object? raw, List<RestaurantAddress> addresses) {
    final visit = LegacyObject(raw, {
      'id',
      'restaurantId',
      'consumeTime',
      'address',
      'eaters',
      'totalCost',
      'comment',
      'foods',
      'index',
      'environmentPictures',
      'autoCost',
    });
    final id = visit.integer('id');
    if (id <= 0 ||
        !visitIds.add(id) ||
        visit.integer('restaurantId') != restaurantId) {
      visit.fail();
    }
    visit.integer('index');
    final address = _address(visit.values['address']);
    if (!addresses.any((entry) => entry.id == address.id)) {
      throw const FormatException('备份中的用餐地点关联不完整，未恢复任何数据。');
    }
    // The source embeds the address snapshot, rather than only its identifier.
    final items = visit.list('foods', omitted: true).map((raw) {
      final dish = _dish(raw, visitId: id);
      return VisitDish(
        dishId: dish.orderInHome >= 0 ? dish.id : '',
        name: dish.name,
        price: dish.price,
        quantity: dish.quantity,
        note: dish.note,
        imagePaths: [...dish.images],
      );
    }).toList();
    final total = visit.number('totalCost');
    if (total < 0) visit.fail();
    final result = Visit(
      id: 'android-visit-$id',
      date: DateTime.fromMillisecondsSinceEpoch(visit.integer('consumeTime')),
      addressId: address.id,
      address: address.fullAddress,
      autoCost: visit.flag('autoCost'),
      totalCost: total,
      companions: legacyStrings(visit.list('eaters')),
      note: visit.text('comment'),
      items: items,
      dishes: items.map((dish) => dish.name).toList(),
      imagePaths: files.images(
        legacyStrings(visit.list('environmentPictures', omitted: true)),
      ),
    );
    final extracted = extractVisitCoupons(result.note);
    result.note = extracted.note;
    result.coupons = extracted.coupons;
    if (result.coupons.isNotEmpty &&
        (result.bill.total * 100).round() != (result.totalCost * 100).round()) {
      result.autoCost = false;
    }
    return result;
  }

  _Dish _dish(Object? raw, {int? visitId}) {
    final source = LegacyObject(raw, {
      'id',
      'restaurantId',
      'consumeRecordId',
      'consumeRecordIndex',
      'name',
      'cover',
      'images',
      'comment',
      'price',
      'quantity',
      'index',
      'orderInHome',
    });
    final id = source.integer('id');
    final recordId = source.integer('consumeRecordId');
    if (id <= 0 ||
        source.integer('restaurantId') != restaurantId ||
        (visitId != null && recordId != visitId)) {
      source.fail();
    }
    source.integer('consumeRecordIndex');
    source.integer('index');
    final price = source.number('price');
    final quantity = source.integer('quantity');
    if (price < 0 || quantity < 1) source.fail();
    final dish = _Dish(
      id: 'android-dish-$id',
      // Android's photo import saves a dish with photos but no name; Gson
      // omits that null name. Keep it empty rather than inventing a dish name.
      name: source.text('name'),
      price: price,
      quantity: quantity,
      note: source.text('comment'),
      images: files.images(
        legacyStrings(source.list('images', omitted: true)),
        cover: source.text('cover'),
      ),
      orderInHome: source.integer('orderInHome'),
    );
    final existing = dishes[id];
    if (existing != null &&
        (existing.name != dish.name ||
            existing.price != dish.price ||
            existing.quantity != dish.quantity ||
            existing.note != dish.note ||
            existing.orderInHome != dish.orderInHome)) {
      throw const FormatException('备份中的餐厅菜品关联冲突，未恢复任何数据。');
    }
    if (existing != null) return existing;
    dishes[id] = dish;
    return dish;
  }
}

class _Dish {
  _Dish({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.note,
    required this.images,
    required this.orderInHome,
  });
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String note;
  final List<String> images;
  final int orderInHome;
}
