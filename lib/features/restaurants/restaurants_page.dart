import '../../ui/menu_bottom_sheet.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/library_widgets.dart';
import '../../ui/widgets.dart';
import 'companion_stats_page.dart';
import 'restaurant_card.dart';
import 'restaurant_editor.dart';
import 'restaurant_filter.dart';
import 'restaurant_search_page.dart';
export 'restaurant_editor.dart' show editRestaurant;
export 'restaurant_card.dart' show RestaurantCard;

List<Restaurant> orderedRestaurants(
  List<Restaurant> source,
  RestaurantSort sort,
) {
  DateTime latest(Restaurant r) => r.records.isEmpty
      ? DateTime(1900)
      : r.records.map((v) => v.date).reduce((a, b) => a.isAfter(b) ? a : b);
  final dates = {for (final r in source) r.id: latest(r)};
  final positions = {for (var i = 0; i < source.length; i++) source[i].id: i};
  return [...source]..sort((a, b) {
    final compared = switch (sort) {
      RestaurantSort.recent => 0,
      RestaurantSort.visits => b.records.length.compareTo(a.records.length),
      RestaurantSort.price => b.averageCost.compareTo(a.averageCost),
    };
    if (compared != 0) return compared;
    final date = dates[b.id]!.compareTo(dates[a.id]!);
    return date != 0 ? date : positions[b.id]!.compareTo(positions[a.id]!);
  });
}

class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({super.key});
  @override
  State<RestaurantsPage> createState() => RestaurantsPageState();
}

class RestaurantsPageState extends State<RestaurantsPage> {
  RestaurantQuery _query = RestaurantQuery();
  final _scroll = ScrollController();
  void scrollToTop() => scrollMenuToTop(context, _scroll);
  void _update(VoidCallback change) {
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _fromStats = false;
  double _rankingOffset = 0;
  Future<void> _filter() async {
    final result = await editRestaurantFilter(context, _query);
    if (result != null && mounted) _update(() => _query = result);
  }

  Future<void> _statistics() async {
    final result = await Navigator.push<RestaurantQuery>(
      context,
      MaterialPageRoute(
        builder: (_) => CompanionStatsPage(
          initialOffset: _rankingOffset,
          onOffset: (offset) => _rankingOffset = offset,
        ),
      ),
    );
    if (result != null && mounted) {
      _update(() {
        _query = result;
        _fromStats = true;
      });
    }
  }

  Future<void> _sort() async {
    final sort = await showMenuBottomSheet<RestaurantSort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '餐厅排序',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (final sort in RestaurantSort.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(RestaurantQuery(sort: sort).sortLabel),
                  trailing: sort == _query.sort
                      ? MenuIcon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, sort),
                ),
            ],
          ),
        ),
      ),
    );
    if (sort != null && mounted) _update(() => _query.sort = sort);
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = MenuScope.of(context).data.restaurants;
    final results = orderedRestaurants(
      restaurants.where(_query.matches).toList(),
      _query.sort,
    );
    final filters = <({String label, VoidCallback remove})>[
      if (_query.category.isNotEmpty)
        (label: _query.category, remove: () => _query.category = ''),
      if (_query.hasRegion)
        (
          label: [
            _query.province,
            _query.city,
            _query.county,
          ].where((v) => v.isNotEmpty).join(' '),
          remove: () {
            _query.province = '';
            _query.city = '';
            _query.county = '';
          },
        ),
      if (_query.start != null || _query.end != null)
        (
          label:
              '${_query.start == null ? '不限' : dayLabel(_query.start!)} 至 ${_query.end == null ? '不限' : dayLabel(_query.end!)}',
          remove: () {
            _query.start = null;
            _query.end = null;
          },
        ),
      if (_query.alone || _query.companionsOnly)
        (
          label: _query.alone
              ? '独自用餐'
              : _query.companions.isEmpty
              ? '有饭伙'
              : _query.companions.join('、'),
          remove: () {
            _query.alone = false;
            _query.companionsOnly = false;
            _query.companions.clear();
          },
        ),
      if (_query.favorite)
        (label: '收藏餐厅', remove: () => _query.favorite = false),
    ];
    return MenuPage(
      title: '餐厅',
      actionsSpacing: 4,
      actions: [
        PageActionButton(
          icon: Icons.search,
          label: '搜索餐厅',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const RestaurantSearchPage(),
            ),
          ),
        ),
        PageActionButton(
          icon: Icons.filter_alt_outlined,
          label: '筛选餐厅',
          badgeCount: filters.length,
          onPressed: _filter,
        ),
        PageActionButton(
          icon: Icons.bar_chart_outlined,
          label: '用餐统计',
          onPressed: _statistics,
        ),
        PageAddButton(label: '添加餐厅', onPressed: () => editRestaurant(context)),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${results.length} 家餐厅',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _sort,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _query.sortLabel,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const MenuIcon(Icons.chevron_right, size: 13),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_fromStats)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _statistics,
                icon: const MenuIcon(Icons.arrow_back, size: 18),
                label: const Text('返回用餐统计'),
              ),
            ),
          if (filters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final filter in filters)
                      InputChip(
                        label: Text(
                          filter.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const MenuIcon(Icons.close, size: 15),
                        onDeleted: () => _update(filter.remove),
                      ),
                    TextButton(
                      onPressed: () => _update(
                        () => _query = RestaurantQuery(sort: _query.sort),
                      ),
                      child: const Text('清除筛选'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: results.isEmpty
                ? EmptyState(
                    icon: _query.active
                        ? Icons.search_off
                        : Icons.storefront_outlined,
                    title: _query.active ? '没有符合条件的餐厅' : '收好值得再去的地方',
                    message: _query.active
                        ? '换个筛选条件，继续找找。'
                        : '点击右上角的＋添加餐厅，再记下吃过的菜和用餐感受。',
                    actionLabel: _query.active ? '查看全部餐厅' : '添加餐厅',
                    onAction: () {
                      if (_query.active) {
                        _update(
                          () => _query = RestaurantQuery(sort: _query.sort),
                        );
                      } else {
                        editRestaurant(context);
                      }
                    },
                  )
                : ListView.separated(
                    controller: _scroll,
                    key: const PageStorageKey('restaurants'),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      120 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 18),
                    itemBuilder: (_, index) => RestaurantCard(
                      key: ValueKey(results[index].id),
                      restaurant: results[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
