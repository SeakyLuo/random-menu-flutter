import 'tag_patterns.dart';
import 'geo_point.dart';
import 'menu_schema.dart';
import 'package:uuid/uuid.dart';

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

class RestaurantDish {
  RestaurantDish({
    required this.id,
    required this.name,
    this.price = 0,
    this.quantity = 1,
    this.note = '',
    this.imagePaths = const [],
  });
  String id;
  String name;
  double price;
  int quantity;
  String note;
  List<String> imagePaths;
  factory RestaurantDish.fromJson(Map<String, dynamic> j) => RestaurantDish(
    id: j['id'] as String,
    name: j['name'] as String,
    price: (j['price'] as num).toDouble(),
    quantity: j['quantity'] as int,
    note: j['note'] as String,
    imagePaths: List<String>.from(j['imagePaths'] as List),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'quantity': quantity,
    'note': note,
    'imagePaths': imagePaths,
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
    this.price = 0,
    this.quantity = 1,
    this.note = '',
    this.imagePaths = const [],
  });
  String dishId;
  String name;
  double price;
  int quantity;
  String note;
  List<String> imagePaths;
  double get cost => price * quantity;
  factory VisitDish.fromJson(Map<String, dynamic> j) => VisitDish(
    dishId: j['dishId'] as String,
    name: j['name'] as String,
    price: (j['price'] as num).toDouble(),
    quantity: j['quantity'] as int,
    note: j['note'] as String,
    imagePaths: List<String>.from(j['imagePaths'] as List),
  );
  Map<String, dynamic> toJson() => {
    'dishId': dishId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'note': note,
    'imagePaths': imagePaths,
  };
}

class Visit {
  Visit({
    required this.id,
    required this.date,
    this.totalCost = 0,
    this.addressId = '',
    this.address = '',
    this.autoCost = false,
    this.items = const [],
    this.companions = const [],
    this.note = '',
    this.dishes = const [],
    this.imagePaths = const [],
  });
  String id;
  DateTime date;
  double totalCost;
  String addressId;
  String address;
  bool autoCost;
  List<VisitDish> items;
  List<String> companions;
  String note;
  List<String> dishes;
  List<String> imagePaths;
  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    totalCost: (j['totalCost'] as num).toDouble(),
    addressId: j['addressId'] as String,
    address: j['address'] as String,
    autoCost: j['autoCost'] as bool,
    items: (j['items'] as List)
        .map((e) => VisitDish.fromJson(e as Map<String, dynamic>))
        .toList(),
    note: j['note'] as String,
    companions: List<String>.from(j['companions'] as List),
    dishes: List<String>.from(j['dishes'] as List),
    imagePaths: List<String>.from(j['imagePaths'] as List),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'totalCost': totalCost,
    'addressId': addressId,
    'address': address,
    'autoCost': autoCost,
    'items': items.map((e) => e.toJson()).toList(),
    'companions': companions,
    'note': note,
    'dishes': dishes,
    'imagePaths': imagePaths,
  };
}

class Restaurant {
  Restaurant({
    required this.id,
    required this.name,
    this.category = '',
    this.addresses = const [],
    this.addressEntries = const [],
    this.note = '',
    this.link = '',
    this.favorite = false,
    this.foods = const [],
    this.records = const [],
  });
  String id;
  String name;
  String category;
  List<String> addresses;
  List<RestaurantAddress> addressEntries;
  String note;
  String link;
  bool favorite;
  List<RestaurantDish> foods;
  List<Visit> records;
  double get averageCost {
    final paid = records.where((v) => v.totalCost > 0);
    final people = paid.fold(0, (n, v) => n + v.companions.length + 1);
    return people == 0 ? 0 : paid.fold(0.0, (n, v) => n + v.totalCost) / people;
  }

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
    id: j['id'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    note: j['note'] as String,
    link: j['link'] as String,
    favorite: j['favorite'] as bool,
    addresses: List<String>.from(j['addresses'] as List),
    addressEntries: (j['addressEntries'] as List)
        .map((e) => RestaurantAddress.fromJson(e as Map<String, dynamic>))
        .toList(),
    foods: (j['foods'] as List)
        .map((e) => RestaurantDish.fromJson(e as Map<String, dynamic>))
        .toList(),
    records: (j['records'] as List)
        .map((e) => Visit.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'addresses': addresses,
    'addressEntries': addressEntries.map((e) => e.toJson()).toList(),
    'note': note,
    'link': link,
    'favorite': favorite,
    'foods': foods.map((e) => e.toJson()).toList(),
    'records': records.map((e) => e.toJson()).toList(),
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
    if (j['version'] != 3) {
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
    'version': 3,
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
