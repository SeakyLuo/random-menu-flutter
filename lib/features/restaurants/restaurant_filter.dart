import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../../ui/library_widgets.dart';

enum RestaurantSort { recent, visits, price }

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
  };
}

Future<RestaurantQuery?> editRestaurantFilter(
  BuildContext context,
  RestaurantQuery query,
) {
  final current = query.copy();
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
  return Navigator.push<RestaurantQuery>(
    context,
    MaterialPageRoute(builder: (_) => _FilterPage(query: current)),
  );
}

class _FilterPage extends StatefulWidget {
  const _FilterPage({required this.query});
  final RestaurantQuery query;
  @override
  State<_FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<_FilterPage> {
  late RestaurantQuery query = widget.query.copy();
  Future<void> dates() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      initialDateRange: query.start == null
          ? null
          : DateTimeRange(start: query.start!, end: query.end!),
    );
    if (result != null && mounted) {
      setState(() {
        query.start = result.start;
        query.end = result.end;
      });
    }
  }

  Widget selection(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: '', child: Text('不限')),
      for (final v in values) DropdownMenuItem(value: v, child: Text(v)),
    ],
    onChanged: (v) => onChanged(v!),
  );
  @override
  Widget build(BuildContext context) {
    final restaurants = MenuScope.of(context).data.restaurants;
    final categories =
        restaurants
            .map((r) => r.category)
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final addresses = restaurants.expand((r) => r.addressEntries).toList();
    List<String> unique(Iterable<String> values) =>
        values.where((v) => v.isNotEmpty).toSet().toList()..sort();
    final provinces = unique(addresses.map((a) => a.province));
    final cities = unique(
      addresses
          .where((a) => query.province.isEmpty || a.province == query.province)
          .map((a) => a.city),
    );
    final counties = unique(
      addresses
          .where(
            (a) =>
                (query.province.isEmpty || a.province == query.province) &&
                (query.city.isEmpty || a.city == query.city),
          )
          .map((a) => a.county),
    );
    final people = unique(
      restaurants.expand((r) => r.records).expand((v) => v.companions),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('筛选餐厅')),
      bottomNavigationBar: FixedPageActions(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  setState(() => query = RestaurantQuery(sort: query.sort)),
              child: const Text('重置'),
            ),
          ),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context, query),
              child: Text('查看 ${restaurants.where(query.matches).length} 家餐厅'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          const SectionTitle('菜系'),
          selection(
            '菜系',
            query.category,
            categories,
            (v) => setState(() => query.category = v),
          ),
          const SectionTitle('用餐时间'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              query.start == null
                  ? '不限日期'
                  : '${dayLabel(query.start!)} 至 ${dayLabel(query.end!)}',
            ),
            trailing: const MenuIcon(Icons.date_range_outlined),
            onTap: dates,
          ),
          if (query.start != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  query.start = null;
                  query.end = null;
                }),
                child: const Text('清除日期'),
              ),
            ),
          const SectionTitle('地区'),
          Text(
            '从已记录的地区中选择；地址未补充地区的餐厅可在不限地区时找到。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          selection(
            '省 / 直辖市',
            query.province,
            provinces,
            (v) => setState(() {
              query.province = v;
              query.city = '';
              query.county = '';
            }),
          ),
          const SizedBox(height: 16),
          selection(
            '城市',
            query.city,
            cities,
            (v) => setState(() {
              query.city = v;
              query.county = '';
            }),
          ),
          const SizedBox(height: 16),
          selection(
            '区 / 县',
            query.county,
            counties,
            (v) => setState(() => query.county = v),
          ),
          const SectionTitle('同行人'),
          const Text('选择多位饭伙时，须在同一次用餐中全部出现。'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('只看独自用餐'),
            value: query.alone,
            onChanged: (v) => setState(() {
              query.alone = v;
              if (v) {
                query.companions.clear();
                query.companionsOnly = false;
              }
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('和饭伙用餐'),
            value: query.companionsOnly,
            onChanged: (v) => setState(() {
              query.companionsOnly = v;
              query.alone = false;
              if (!v) query.companions.clear();
            }),
          ),
          if (people.isEmpty)
            Text(
              '记录用餐时填写同行人，即可在这里筛选。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final person in people)
                FilterChip(
                  label: Text(person),
                  selected: query.companions.contains(person),
                  onSelected: (selected) => setState(() {
                    query.alone = false;
                    query.companionsOnly = true;
                    if (selected) {
                      query.companions.add(person);
                    } else {
                      query.companions.remove(person);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('只看收藏餐厅'),
            value: query.favorite,
            onChanged: (v) => setState(() => query.favorite = v),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
