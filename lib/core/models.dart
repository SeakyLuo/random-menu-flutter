import 'tag_patterns.dart';
import 'currency.dart';
export 'currency.dart';
import 'geo_point.dart';
import 'menu_schema.dart';
import 'package:uuid/uuid.dart';
import 'visit_coupon.dart';
import 'visit_package.dart';
export 'visit_coupon.dart';
export 'visit_package.dart';

String newId() => const Uuid().v4();

class Recipe {
  Recipe({
    required this.id,
    required this.name,
    this.note = '',
    this.tags = const [],
    this.imagePaths = const [],
    this.favorite = false,
    this.hiddenRounds = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  String id;
  String name;
  String note;
  List<String> tags;
  List<String> imagePaths;
  bool favorite;
  int hiddenRounds;
  DateTime createdAt;
  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    id: j['id'] as String,
    name: j['name'] as String,
    note: j['note'] as String,
    tags: List<String>.from(j['tags'] as List),
    imagePaths: List<String>.from(j['imagePaths'] as List),
    favorite: j['favorite'] as bool,
    hiddenRounds: j['hiddenRounds'] as int,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'tags': tags,
    'imagePaths': imagePaths,
    'favorite': favorite,
    'hiddenRounds': hiddenRounds,
    'createdAt': createdAt.toIso8601String(),
  };
}

class RestaurantAddress {
  RestaurantAddress({
    required this.id,
    this.province = '',
    this.city = '',
    this.county = '',
    this.detail = '',
    this.location,
  });
  String id;
  String province;
  String city;
  String county;
  String detail;
  GeoPoint? location;
  String get fullAddress =>
      '$province${city == province ? '' : city}$county$detail';
  factory RestaurantAddress.fromJson(Map<String, dynamic> j) =>
      RestaurantAddress(
        id: j['id'] as String,
        province: j['province'] as String,
        city: j['city'] as String,
        county: j['county'] as String,
        detail: j['detail'] as String,
        location: j['location'] == null
            ? null
            : GeoPoint.fromJson(j['location'] as Map<String, dynamic>),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'province': province,
    'city': city,
    'county': county,
    'detail': detail,
    'location': location?.toJson(),
  };
}

class VisitDish {
  VisitDish({
    required this.dishId,
    required this.name,
    this.packageId,
    this.isDish = true,
    this.price = 0,
    this.quantity = 1,
    this.note = '',
    this.imagePaths = const [],
  });
  String dishId;
  bool isDish;
  String? packageId;
  String name;
  double price;
  int quantity;
  String note;
  List<String> imagePaths;
  double get cost => price * quantity;
  factory VisitDish.fromJson(Map<String, dynamic> j) => VisitDish(
    dishId: j['dishId'] as String,
    isDish: j['isDish'] as bool,
    packageId: j['packageId'] as String?,
    name: j['name'] as String,
    price: (j['price'] as num).toDouble(),
    quantity: j['quantity'] as int,
    note: j['note'] as String,
    imagePaths: List<String>.from(j['imagePaths'] as List),
  );
  Map<String, dynamic> toJson() => {
    'dishId': dishId,
    'isDish': isDish,
    'packageId': packageId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'note': note,
    'imagePaths': imagePaths,
  };
}

double visitSubtotal(List<VisitDish> items, List<VisitPackage> packages) =>
    items
        .where((i) => i.packageId == null)
        .fold(0.0, (sum, i) => sum + i.cost) +
    packages.fold(0.0, (sum, p) => sum + p.totalPrice);

class Visit {
  Visit({
    required this.id,
    required this.date,
    this.totalCost = 0,
    this.currency = MenuCurrency.cny,
    this.addressId = '',
    this.address = '',
    this.autoCost = false,
    this.items = const [],
    this.coupons = const [],
    this.packages = const [],
    this.companions = const [],
    this.note = '',
    this.dishes = const [],
    this.imagePaths = const [],
  });
  String id;
  DateTime date;
  double totalCost;
  MenuCurrency currency;
  String addressId;
  String address;
  bool autoCost;
  List<VisitDish> items;
  List<VisitCoupon> coupons;
  List<VisitPackage> packages;
  VisitPackage? packageFor(VisitDish dish) => dish.packageId == null
      ? null
      : packages.firstWhere((p) => p.id == dish.packageId);
  void validatePackages() {
    final ids = packages.map((p) => p.id).toSet();
    if (ids.length != packages.length ||
        items.any((i) => i.packageId != null && !ids.contains(i.packageId))) {
      throw const FormatException('菜品与套餐关联不完整');
    }
  }

  VisitBill get bill => VisitBill(visitSubtotal(items, packages), coupons);
  List<String> companions;
  String note;
  List<String> dishes;
  List<String> imagePaths;
  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    totalCost: (j['totalCost'] as num).toDouble(),
    currency: MenuCurrency.fromCode(j['currency'] as String),
    addressId: j['addressId'] as String,
    address: j['address'] as String,
    autoCost: j['autoCost'] as bool,
    packages: (j['packages'] as List)
        .map((e) => VisitPackage.fromJson(e as Map<String, dynamic>))
        .toList(),
    coupons: (j['coupons'] as List)
        .map((e) => VisitCoupon.fromJson(e as Map<String, dynamic>))
        .toList(),
    items: (j['items'] as List)
        .map((e) => VisitDish.fromJson(e as Map<String, dynamic>))
        .toList(),
    note: j['note'] as String,
    companions: List<String>.from(j['companions'] as List),
    dishes: List<String>.from(j['dishes'] as List),
    imagePaths: List<String>.from(j['imagePaths'] as List),
  );
  Map<String, dynamic> toJson({bool includeFoods = true}) => {
    'id': id,
    'date': date.toIso8601String(),
    'totalCost': totalCost,
    'currency': currency.code,
    'addressId': addressId,
    'address': address,
    'autoCost': autoCost,
    if (includeFoods) 'packages': packages.map((p) => p.toJson()).toList(),
    'coupons': coupons.map((coupon) => coupon.toJson()).toList(),
    if (includeFoods) 'items': items.map((e) => e.toJson()).toList(),
    'companions': companions,
    'note': note,
    if (includeFoods) 'dishes': dishes,
    'imagePaths': imagePaths,
  };
}

class Restaurant {
  Restaurant({
    required this.id,
    required this.name,
    this.categories = const [],
    this.addresses = const [],
    this.addressEntries = const [],
    this.note = '',
    this.link = '',
    this.favorite = false,
    this.coverDishId,
    this.records = const [],
  });
  String id;
  String name;
  List<String> categories;
  List<String> addresses;
  List<RestaurantAddress> addressEntries;
  String note;
  String link;
  bool favorite;
  String? coverDishId;
  List<Visit> records;
  Map<MenuCurrency, double> get averageCosts {
    final totals = <MenuCurrency, double>{};
    final people = <MenuCurrency, int>{};
    for (final visit in records) {
      if (visit.totalCost <= 0) continue;
      totals.update(
        visit.currency,
        (value) => value + visit.totalCost,
        ifAbsent: () => visit.totalCost,
      );
      people.update(
        visit.currency,
        (value) => value + visit.companions.length + 1,
        ifAbsent: () => visit.companions.length + 1,
      );
    }
    return totals.map(
      (currency, total) => MapEntry(currency, total / people[currency]!),
    );
  }

  MenuCurrency get priceCurrency {
    final paid = records.where((visit) => visit.totalCost > 0).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return paid.isEmpty ? MenuCurrency.cny : paid.first.currency;
  }

  double get averageCost => averageCosts[priceCurrency] ?? 0;

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
    id: j['id'] as String,
    name: j['name'] as String,
    categories: List<String>.from(j['categories'] as List),
    note: j['note'] as String,
    link: j['link'] as String,
    favorite: j['favorite'] as bool,
    coverDishId: j['coverDishId'] as String?,
    addresses: List<String>.from(j['addresses'] as List),
    addressEntries: (j['addressEntries'] as List)
        .map((e) => RestaurantAddress.fromJson(e as Map<String, dynamic>))
        .toList(),
    records: (j['records'] as List)
        .map((e) => Visit.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  Map<String, dynamic> toJson({bool includeRecords = true}) => {
    'id': id,
    'name': name,
    'categories': categories,
    'addresses': addresses,
    'addressEntries': addressEntries.map((e) => e.toJson()).toList(),
    'note': note,
    'link': link,
    'favorite': favorite,
    'coverDishId': coverDishId,
    if (includeRecords) 'records': records.map((e) => e.toJson()).toList(),
  };
}

class MenuData {
  MenuData({
    this.recipes = const [],
    this.restaurants = const [],
    this.toCook = const [],
    this.toEat = const [],
    this.dislikes = const [],
    this.note = '',
    this.themeMode = 'system',
    this.autoTag = true,
    this.tagRules = const {},
    this.selectedMenu = const [],
    this.recipeDraft,
    this.recipeDraftSourceId,
    this.legacyImagePaths = const [],
    this.recipeTags = const [],
    this.restaurantCategories = const [],
    this.recipeSearchHistory = const [],
    this.restaurantSearchHistory = const [],
    this.recipeTagSort = 'default',
    this.patternTagRules = const {},
  });
  // Stable catalog identities are internal; portable backups retain names.
  Map<String, int> recipePositions = {};
  Map<String, int> restaurantPositions = {};
  Map<String, String> recipeTagIds = {};
  Map<String, String> restaurantCategoryIds = {};
  List<Recipe> recipes;
  List<Restaurant> restaurants;
  List<String> toCook;
  List<String> toEat;
  List<String> dislikes;
  String note;
  String themeMode;
  bool autoTag;
  Map<String, List<String>> tagRules;
  List<String> selectedMenu;
  Recipe? recipeDraft;
  String? recipeDraftSourceId;
  List<String> legacyImagePaths;
  List<String> recipeTags;
  List<String> restaurantCategories;
  List<String> recipeSearchHistory;
  List<String> restaurantSearchHistory;
  String recipeTagSort;
  Map<String, List<String>> patternTagRules;
  Future<List<String>> inferRecipeTags(String name) async {
    if (!autoTag) return [];
    final result = <String>{};
    for (final rule in tagRules.entries) {
      if (rule.value.any(name.contains)) result.add(rule.key);
    }
    final matched = await matchLegacyPatterns(
      patternTagRules.keys.toList(),
      name,
    );
    for (final pattern in matched) {
      result.addAll(patternTagRules[pattern]!);
    }
    return result.toList();
  }

  factory MenuData.fromJson(Map<String, dynamic> j) {
    if (j['version'] == 1) j = upgradeMenuV1(j);
    if (j['version'] == 2) j = upgradeMenuV2(j);
    if (j['version'] == 3) j = upgradeMenuV3(j);
    if (j['version'] == 4) j = upgradeMenuV4(j);
    if (j['version'] == 5) j = upgradeMenuV5(j);
    if (j['version'] == 6) j = upgradeMenuV6(j);
    if (j['version'] == 7) j = upgradeMenuV7(j);
    if (j['version'] == 8) j = upgradeMenuV8(j);
    if (j['version'] == 9) j = upgradeMenuV9(j);
    if (j['version'] == 10) j = upgradeMenuV10(j);
    if (j['version'] != 11) {
      throw const FormatException('Unsupported menu format');
    }
    return MenuData(
      recipeDraftSourceId: j['recipeDraftSourceId'] as String?,
      legacyImagePaths: List<String>.from(j['legacyImagePaths'] as List),
      recipeDraft: j['recipeDraft'] == null
          ? null
          : Recipe.fromJson(j['recipeDraft'] as Map<String, dynamic>),
      recipeTags: List<String>.from(j['recipeTags'] as List),
      restaurantCategories: List<String>.from(
        j['restaurantCategories'] as List,
      ),
      recipeSearchHistory: List<String>.from(j['recipeSearchHistory'] as List),
      restaurantSearchHistory: List<String>.from(
        j['restaurantSearchHistory'] as List,
      ),
      recipeTagSort: j['recipeTagSort'] as String,
      patternTagRules: (j['patternTagRules'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      ),
      recipes: (j['recipes'] as List)
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
          .toList(),
      restaurants: (j['restaurants'] as List)
          .map((e) => Restaurant.fromJson(e as Map<String, dynamic>))
          .toList(),
      toCook: List<String>.from(j['toCook'] as List),
      toEat: List<String>.from(j['toEat'] as List),
      dislikes: List<String>.from(j['dislikes'] as List),
      note: j['note'] as String,
      themeMode: j['themeMode'] as String,
      autoTag: j['autoTag'] as bool,
      selectedMenu: List<String>.from(j['selectedMenu'] as List),
      tagRules: (j['tagRules'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, List<String>.from(v as List)),
      ),
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 11,
    'recipes': recipes.map((e) => e.toJson()).toList(),
    'restaurants': restaurants.map((e) => e.toJson()).toList(),
    'toCook': toCook,
    'toEat': toEat,
    'dislikes': dislikes,
    'note': note,
    'themeMode': themeMode,
    'autoTag': autoTag,
    'tagRules': tagRules,
    'selectedMenu': selectedMenu,
    'recipeDraft': recipeDraft?.toJson(),
    'recipeDraftSourceId': recipeDraftSourceId,
    'legacyImagePaths': legacyImagePaths,
    'recipeTags': recipeTags,
    'restaurantCategories': restaurantCategories,
    'recipeSearchHistory': recipeSearchHistory,
    'restaurantSearchHistory': restaurantSearchHistory,
    'recipeTagSort': recipeTagSort,
    'patternTagRules': patternTagRules,
  };
}
