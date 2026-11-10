import '../../core/tag_path.dart';
import 'dart:convert';
import '../../core/models.dart';
import 'restaurant_filter.dart';

enum DiningBreakdown {
  companions('饭搭子统计'),
  cuisines('菜系统计'),
  counties('地址统计'),
  amounts('人均消费统计'),
  quarters('时间统计');

  const DiningBreakdown(this.title);
  final String title;
}

enum DiningTimeUnit {
  year(12),
  quarter(3),
  month(1);

  const DiningTimeUnit(this.months);
  final int months;
}

class DiningEntry {
  const DiningEntry(this.restaurant, this.visit);
  final Restaurant restaurant;
  final Visit visit;
}

class DiningGroup {
  const DiningGroup(
    this.key,
    this.label,
    this.entries, {
    this.exactCuisine = false,
    this.countRestaurants = false,
    this.detail = '',
    this.province = '',
    this.city = '',
    this.county = '',
    this.regionLevel = RestaurantRegionLevel.county,
    this.amountBand,
    this.start,
    this.end,
  });
  final bool exactCuisine, countRestaurants;
  final String key, label;
  final String detail, province, city, county;
  final List<DiningEntry> entries;
  final DiningAmountBand? amountBand;
  final DateTime? start, end;
  final RestaurantRegionLevel regionLevel;
  int get count => countRestaurants ? restaurantCount : entries.length;
  String get unit => countRestaurants ? '家' : '次';
  int get restaurantCount => entries.map((e) => e.restaurant.id).toSet().length;
}

class DiningAmountBand {
  const DiningAmountBand(this.lower, this.upper, this.label);
  final int lower;
  final int? upper;
  final String label;
  String get key => '$lower';
  bool contains(double amount) =>
      amount >= lower && (upper == null || amount < upper!);

  static const values = [
    DiningAmountBand(0, 50, '0–50'),
    DiningAmountBand(50, 100, '50–100'),
    DiningAmountBand(100, 200, '100–200'),
    DiningAmountBand(200, 300, '200–300'),
    DiningAmountBand(300, 500, '300–500'),
    DiningAmountBand(500, null, '500+'),
  ];

  static const details = [
    DiningAmountBand(0, 50, '0–50'),
    DiningAmountBand(50, 100, '50–100'),
    DiningAmountBand(100, 150, '100–150'),
    DiningAmountBand(150, 200, '150–200'),
    DiningAmountBand(200, 300, '200–300'),
    DiningAmountBand(300, 400, '300–400'),
    DiningAmountBand(400, 500, '400–500'),
    DiningAmountBand(500, 600, '500–600'),
    DiningAmountBand(600, 800, '600–800'),
    DiningAmountBand(800, 1000, '800–1000'),
    DiningAmountBand(1000, null, '1k+'),
  ];
}

class DiningStatistics {
  DiningStatistics(List<Restaurant> restaurants) {
    for (final restaurant in restaurants) {
      _prices[restaurant.id] = restaurant.averageCosts;
      final addresses = {
        for (final address in restaurant.addressEntries) address.id: address,
      };
      for (final visit in restaurant.records) {
        final entry = DiningEntry(restaurant, visit);
        entries.add(entry);
        if (restaurant.categories.isEmpty) {
          _cuisines.putIfAbsent('', () => []).add(entry);
        } else {
          for (final tag in {
            for (final selected in restaurant.categories)
              ...tagPathPrefixes(selected),
          }) {
            _cuisines.putIfAbsent(tag, () => []).add(entry);
          }
        }
        final branch = addresses[visit.addressId];
        _places.add((
          entry,
          (branch?.province ?? '', branch?.city ?? '', branch?.county ?? ''),
        ));
        if (visit.companions.isEmpty) {
          alone.add(entry);
        } else {
          for (final name in visit.companions.toSet()) {
            _companions.putIfAbsent(name, () => []).add(entry);
          }
        }
      }
    }
  }

  final entries = <DiningEntry>[];
  final alone = <DiningEntry>[];
  final _companions = <String, List<DiningEntry>>{};
  final _cuisines = <String, List<DiningEntry>>{};
  final _prices = <String, Map<MenuCurrency, double>>{};
  final _places = <(DiningEntry, (String, String, String))>[];

  int get restaurantCount => entries.map((e) => e.restaurant.id).toSet().length;
  int get cuisineCount => _cuisines.keys
      .where((key) => key.isNotEmpty && !key.contains('/'))
      .length;

  double averageVisitsPerPeriod(DiningTimeUnit unit) =>
      entries.length / _timeGroups(unit).length;

  double? averageCost(MenuCurrency currency) {
    var total = 0.0;
    var diners = 0;
    for (final entry in entries) {
      final visit = entry.visit;
      if (visit.currency != currency || visit.totalCost <= 0) continue;
      total += visit.totalCost;
      diners += visit.companions.length + 1;
    }
    return diners == 0 ? null : total / diners;
  }

  List<DiningGroup> _rank(
    Map<String, List<DiningEntry>> groups, {
    bool tagLabels = false,
  }) =>
      [
        for (final entry in groups.entries)
          DiningGroup(
            entry.key,
            entry.key.isEmpty
                ? '未分类'
                : tagLabels
                ? tagPathLabel(entry.key)
                : entry.key,
            entry.value,
            countRestaurants: tagLabels,
          ),
      ]..sort((a, b) {
        final count = b.count.compareTo(a.count);
        return count == 0 ? a.label.compareTo(b.label) : count;
      });

  List<DiningGroup> groups(
    DiningBreakdown kind,
    MenuCurrency currency, {
    List<DiningAmountBand> amountBands = DiningAmountBand.values,
    DiningTimeUnit timeUnit = DiningTimeUnit.quarter,
    int? recentPeriods,
    bool detailedTags = false,
    RestaurantRegionLevel regionLevel = RestaurantRegionLevel.county,
  }) => switch (kind) {
    DiningBreakdown.companions => _rank(_companions),
    DiningBreakdown.cuisines => _rank({
      for (final entry in _cuisines.entries)
        if (entry.key.contains('/') == detailedTags) entry.key: entry.value,
    }, tagLabels: true),
    DiningBreakdown.counties => _regionGroups(regionLevel),
    DiningBreakdown.quarters => _timeGroups(timeUnit, recentPeriods),
    DiningBreakdown.amounts => [
      for (final band in amountBands)
        DiningGroup(band.key, band.label, [
          for (final entry in entries)
            if (entry.visit.currency == currency &&
                entry.visit.totalCost > 0 &&
                band.contains(
                  (_prices[entry.restaurant.id]![currency]! * 100).round() /
                      100,
                ))
              entry,
        ], amountBand: band),
    ].where((group) => group.count > 0).toList(),
  };

  List<DiningGroup> _timeGroups(DiningTimeUnit unit, [int? recentPeriods]) {
    if (entries.isEmpty) return [];
    final periodsPerYear = 12 ~/ unit.months;
    int periodFor(DateTime date) =>
        date.year * periodsPerYear + (date.month - 1) ~/ unit.months;
    final periods = <int, List<DiningEntry>>{};
    for (final entry in entries) {
      periods.putIfAbsent(periodFor(entry.visit.date), () => []).add(entry);
    }
    final keys = periods.keys.toList()..sort();
    final current = periodFor(DateTime.now());
    final last = recentPeriods != null
        ? current
        : keys.last > current
        ? keys.last
        : current;
    final first = recentPeriods == null
        ? keys.first
        : current - recentPeriods + 1;
    return [
      for (var period = last; period >= first; period--)
        DiningGroup(
          '$period',
          switch (unit) {
            DiningTimeUnit.year => '${period ~/ periodsPerYear}年',
            DiningTimeUnit.quarter =>
              '${period ~/ periodsPerYear}年 第${period % periodsPerYear + 1}季度',
            DiningTimeUnit.month =>
              '${period ~/ periodsPerYear}年 ${period % periodsPerYear + 1}月',
          },
          periods[period] ?? [],
          start: DateTime(
            period ~/ periodsPerYear,
            period % periodsPerYear * unit.months + 1,
          ),
          end: DateTime(
            period ~/ periodsPerYear,
            period % periodsPerYear * unit.months + unit.months + 1,
            0,
          ),
        ),
    ];
  }

  List<DiningGroup> _regionGroups(RestaurantRegionLevel level) {
    final regions = <String, (String, String, String)>{};
    final groups = <String, List<DiningEntry>>{};
    final names = <String, String>{};
    for (final (entry, place) in _places) {
      final region = switch (level) {
        RestaurantRegionLevel.province => (place.$1, '', ''),
        RestaurantRegionLevel.city => (place.$1, place.$2, ''),
        RestaurantRegionLevel.county => place,
      };
      final name = switch (level) {
        RestaurantRegionLevel.province => region.$1,
        RestaurantRegionLevel.city => region.$2,
        RestaurantRegionLevel.county => region.$3,
      };
      final key = name.isEmpty
          ? ''
          : jsonEncode([region.$1, region.$2, region.$3]);
      regions[key] = name.isEmpty ? ('', '', '') : region;
      names[key] = name;
      groups.putIfAbsent(key, () => []).add(entry);
    }
    final nameCounts = <String, int>{};
    for (final name in names.values) {
      nameCounts.update(name, (count) => count + 1, ifAbsent: () => 1);
    }
    return [
      for (final entry in groups.entries)
        DiningGroup(
          entry.key,
          entry.key.isEmpty
              ? switch (level) {
                  RestaurantRegionLevel.province => '未填写省份',
                  RestaurantRegionLevel.city => '未填写城市',
                  RestaurantRegionLevel.county => '未填写区县',
                }
              : names[entry.key]!,
          entry.value,
          regionLevel: level,
          province: regions[entry.key]!.$1,
          city: regions[entry.key]!.$2,
          county: regions[entry.key]!.$3,
          detail: nameCounts[names[entry.key]]! > 1
              ? {regions[entry.key]!.$1, regions[entry.key]!.$2}
                    .where(
                      (name) => name.isNotEmpty && name != names[entry.key],
                    )
                    .join(' · ')
              : '',
        ),
    ]..sort((a, b) {
      final count = b.count.compareTo(a.count);
      return count != 0 ? count : a.key.compareTo(b.key);
    });
  }
}

RestaurantQuery diningGroupFilter(
  DiningBreakdown kind,
  DiningGroup group,
  MenuCurrency currency,
) {
  final query = RestaurantQuery();
  switch (kind) {
    case DiningBreakdown.companions:
      query.alone = group.key.isEmpty;
      query.companion = group.key;
    case DiningBreakdown.cuisines:
      query.categories = group.key.isEmpty ? [] : [group.key];
      query.uncategorized = group.key.isEmpty;
      query.exactCategories = group.exactCuisine;
    case DiningBreakdown.counties:
      query.province = group.province;
      query.city = group.city;
      query.county = group.county;
      query.withoutRegion = group.key.isEmpty ? group.regionLevel : null;
    case DiningBreakdown.quarters:
      query.start = group.start;
      query.end = group.end;
    case DiningBreakdown.amounts:
      final band = group.amountBand!;
      query.currency = currency;
      query.minPrice = band.lower.toDouble();
      query.maxPrice = band.upper == null ? null : band.upper! - .01;
  }
  return query;
}
