import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_bottom_sheet.dart';
import 'restaurant_filter_sheet.dart';

enum RestaurantSort { recent, visits, price, nearest }

class RestaurantQuery {
  RestaurantQuery({
    this.category = '',
    this.companionsOnly = false,
    this.province = '',
    this.city = '',
    this.county = '',
    this.start,
    this.end,
    Set<String>? companions,
    this.alone = false,
    this.favorite = false,
    this.sort = RestaurantSort.recent,
  }) : companions = companions ?? {};
  String category;
  bool companionsOnly;
  String province;
  String city;
  String county;
  DateTime? start;
  DateTime? end;
  Set<String> companions;
  bool alone;
  bool favorite;
  RestaurantSort sort;
  bool get hasRegion =>
      province.isNotEmpty || city.isNotEmpty || county.isNotEmpty;
  bool get hasRecords =>
      start != null ||
      end != null ||
      companions.isNotEmpty ||
      alone ||
      companionsOnly;
  bool get active => hasRegion || hasRecords || favorite || category.isNotEmpty;
  RestaurantQuery copy() => RestaurantQuery(
    category: category,
    companionsOnly: companionsOnly,
    province: province,
    city: city,
    county: county,
    start: start,
    end: end,
    companions: {...companions},
    alone: alone,
    favorite: favorite,
    sort: sort,
  );
  bool matchesAddress(RestaurantAddress a) =>
      (province.isEmpty || a.province == province) &&
      (city.isEmpty || a.city == city) &&
      (county.isEmpty || a.county == county);
  bool matchesVisit(Restaurant r, Visit v) =>
      (start == null || !v.date.isBefore(start!)) &&
      (end == null || v.date.isBefore(end!.add(const Duration(days: 1)))) &&
      (!alone || v.companions.isEmpty) &&
      (!companionsOnly ||
          (v.companions.isNotEmpty && companions.every(v.companions.contains)));
  bool matches(Restaurant r) =>
      (!favorite || r.favorite) &&
      (category.isEmpty || r.category == category) &&
      (!hasRegion || r.addressEntries.any(matchesAddress)) &&
      (!hasRecords || r.records.any((v) => matchesVisit(r, v)));
  String get sortLabel => switch (sort) {
    RestaurantSort.recent => '最近到店',
    RestaurantSort.visits => '消费次数降序',
    RestaurantSort.price => '人均价格降序',
    RestaurantSort.nearest => '离我最近',
  };
}

Future<RestaurantQuery?> editRestaurantFilter(
  BuildContext context,
  RestaurantQuery query,
) {
  final current = query.copy()
    ..alone = false
    ..favorite = false
    ..companionsOnly = query.companions.isNotEmpty;
  final addresses = MenuScope.of(
    context,
  ).data.restaurants.expand((r) => r.addressEntries).toList();
  // Address edits can remove a region that was selected by the previous filter.
  if (current.province.isNotEmpty &&
      !addresses.any((a) => a.province == current.province)) {
    current.province = '';
    current.city = '';
    current.county = '';
  }
  if (current.city.isNotEmpty &&
      !addresses.any(
        (a) =>
            (current.province.isEmpty || a.province == current.province) &&
            a.city == current.city,
      )) {
    current.city = '';
    current.county = '';
  }
  if (current.county.isNotEmpty &&
      !addresses.any(
        (a) =>
            (current.province.isEmpty || a.province == current.province) &&
            (current.city.isEmpty || a.city == current.city) &&
            a.county == current.county,
      )) {
    current.county = '';
  }
  return showMenuBottomSheet<RestaurantQuery>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(
      maxWidth: 560,
      maxHeight: MediaQuery.sizeOf(context).height * .88,
    ),
    builder: (_) => RestaurantFilterSheet(query: current),
  );
}
