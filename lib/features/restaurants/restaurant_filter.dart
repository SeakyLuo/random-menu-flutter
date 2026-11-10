import '../../core/tag_path.dart';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_bottom_sheet.dart';
import 'restaurant_filter_sheet.dart';

enum RestaurantRegionLevel { province, city, county }

enum RestaurantSort { recent, visits, price, nearest }

class RestaurantQuery {
  RestaurantQuery({
    this.categories = const [],
    this.exactCategories = false,
    this.companion = '',
    this.province = '',
    this.city = '',
    this.county = '',
    this.address = '',
    this.withoutRegion,
    this.uncategorized = false,
    this.start,
    this.end,
    this.currency = MenuCurrency.cny,
    this.minPrice,
    this.maxPrice,
    this.alone = false,
    this.favorite = false,
    this.sort = RestaurantSort.recent,
  });
  List<String> categories;
  bool exactCategories;
  String companion;
  String province;
  String city;
  String county;
  String address;
  RestaurantRegionLevel? withoutRegion;
  bool uncategorized;
  DateTime? start;
  DateTime? end;
  MenuCurrency currency;
  double? minPrice;
  double? maxPrice;
  bool alone;
  bool favorite;
  RestaurantSort sort;
  bool get hasRegion =>
      province.isNotEmpty || city.isNotEmpty || county.isNotEmpty;
  bool get hasLocation =>
      hasRegion || address.isNotEmpty || withoutRegion != null;
  bool get hasCategory => categories.isNotEmpty || uncategorized;
  bool get hasRecords =>
      start != null || end != null || companion.isNotEmpty || alone;
  bool get hasPrice => minPrice != null || maxPrice != null;
  bool get active =>
      hasLocation || hasRecords || hasPrice || favorite || hasCategory;
  RestaurantQuery copy() => RestaurantQuery(
    categories: [...categories],
    exactCategories: exactCategories,
    companion: companion,
    province: province,
    city: city,
    county: county,
    address: address,
    withoutRegion: withoutRegion,
    uncategorized: uncategorized,
    start: start,
    end: end,
    currency: currency,
    minPrice: minPrice,
    maxPrice: maxPrice,
    alone: alone,
    favorite: favorite,
    sort: sort,
  );
  bool matchesAddress(RestaurantAddress a) =>
      (province.isEmpty || a.province == province) &&
      (city.isEmpty || a.city == city) &&
      (county.isEmpty || a.county == county) &&
      (address.isEmpty || a.detail == address) &&
      switch (withoutRegion) {
        null => true,
        RestaurantRegionLevel.province => a.province.isEmpty,
        RestaurantRegionLevel.city => a.city.isEmpty,
        RestaurantRegionLevel.county => a.county.isEmpty,
      };
  bool _matchesVisitAddress(Restaurant r, Visit v) {
    if (!hasLocation) return true;
    final branch = r.addressEntries
        .where((a) => a.id == v.addressId)
        .firstOrNull;
    if (branch == null) {
      return withoutRegion != null && !hasRegion && address.isEmpty;
    }
    return matchesAddress(branch);
  }

  bool matchesVisit(Restaurant r, Visit v) =>
      (start == null || !v.date.isBefore(start!)) &&
      (end == null || v.date.isBefore(end!.add(const Duration(days: 1)))) &&
      (!alone || v.companions.isEmpty) &&
      (companion.isEmpty || v.companions.contains(companion)) &&
      _matchesVisitAddress(r, v);
  bool matchesPrice(Restaurant r) {
    if (!hasPrice) return true;
    final price = ((r.averageCosts[currency] ?? 0) * 100).round() / 100;
    return price > 0 &&
        (minPrice == null || price >= minPrice!) &&
        (maxPrice == null || price <= maxPrice!);
  }

  bool matches(Restaurant r) =>
      (!favorite || r.favorite) &&
      categories.every(
        (selected) => r.categories.any(
          (tag) => exactCategories
              ? tag == selected
              : tagPathContains(selected, tag),
        ),
      ) &&
      (!uncategorized || r.categories.isEmpty) &&
      matchesPrice(r) &&
      (hasRecords || (hasLocation && r.records.isNotEmpty)
          ? r.records.any((v) => matchesVisit(r, v))
          : !hasLocation || r.addressEntries.any(matchesAddress));
  String get sortLabel => switch (sort) {
    RestaurantSort.recent => '最近到店',
    RestaurantSort.visits => '消费次数降序',
    RestaurantSort.price => '按人均降序',
    RestaurantSort.nearest => '离我最近',
  };
}

Future<RestaurantQuery?> editRestaurantFilter(
  BuildContext context,
  RestaurantQuery query,
) {
  final current = query.copy();
  // Address edits can remove a region that was selected by the previous filter.
  // Nationwide picker data now keeps that region selectable independently.
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
