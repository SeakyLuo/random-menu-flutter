import 'restaurant_cover_batch.dart';
import '../../ui/search_page_route.dart';
import 'restaurant_grid.dart';
import '../../ui/library_layout.dart';
import '../../ui/menu_action_sheet.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../core/geo_point.dart';
import 'restaurant_distance.dart';
import '../../ui/menu_icon.dart';
import '../../ui/library_widgets.dart';
import '../../ui/widgets.dart';
import 'dining_stats_page.dart';
import 'restaurant_card.dart';
import 'restaurant_editor.dart';
import 'restaurant_filter.dart';
import 'restaurant_search_page.dart';
import 'restaurant_quick_create.dart';
import '../../ui/menu_popup.dart';
export 'restaurant_editor.dart' show editRestaurant;
export 'restaurant_card.dart' show RestaurantCard;

List<Restaurant> orderedRestaurants(
  List<Restaurant> source,
  RestaurantSort sort, {
  Map<String, RestaurantDistance> distances = const {},
}) {
  DateTime latest(Restaurant r) => r.records.isEmpty
      ? DateTime(1900)
      : r.records.map((v) => v.date).reduce((a, b) => a.isAfter(b) ? a : b);
  final dates = {for (final r in source) r.id: latest(r)};
  final positions = {for (var i = 0; i < source.length; i++) source[i].id: i};
  return [...source]..sort((a, b) {
    final compared = switch (sort) {
      RestaurantSort.recent => 0,
      RestaurantSort.visits => b.records.length.compareTo(a.records.length),
      RestaurantSort.price =>
        a.priceCurrency != b.priceCurrency
            ? a.priceCurrency.index.compareTo(b.priceCurrency.index)
            : b.averageCost.compareTo(a.averageCost),
      RestaurantSort.nearest =>
        (distances[a.id]?.meters ?? double.infinity).compareTo(
          distances[b.id]?.meters ?? double.infinity,
        ),
    };
    if (compared != 0) return compared;
    final date = dates[b.id]!.compareTo(dates[a.id]!);
    return date != 0 ? date : positions[b.id]!.compareTo(positions[a.id]!);
  });
}

class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({super.key}) : initialQuery = null;
  const RestaurantsPage.filtered({super.key, required RestaurantQuery query})
    : initialQuery = query;
  final RestaurantQuery? initialQuery;
  @override
  State<RestaurantsPage> createState() => RestaurantsPageState();
}

class RestaurantsPageState extends State<RestaurantsPage> {
  late RestaurantQuery _query =
      widget.initialQuery?.copy() ?? RestaurantQuery();
  bool get _standalone => widget.initialQuery != null;
  final _scroll = ScrollController();
  GeoPoint? _origin;
  bool _locating = false;
  bool _creating = false;
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

  Future<void> _quickCreate() async {
    if (_creating) return;
    final store = MenuScope.of(context);
    setState(() => _creating = true);
    await performAction(context, () async {
      final paths = await store.photos.pick(readLocation: true);
      if (paths.isEmpty) return;
      try {
        final draft = await buildRestaurantFromPhotos(paths);
        if (!mounted) return;
        if (draft.missingDates) {
          showToast(context, '部分照片没有拍摄时间，请核对消费日期');
        }
        await editRestaurant(
          context,
          initialAddresses: draft.addresses,
          initialRecords: draft.records,
        );
      } finally {
        await Future.wait(paths.map(store.photos.releaseSelection));
      }
    });
    if (mounted) setState(() => _creating = false);
  }

  Future<void> _filter() async {
    final result = await editRestaurantFilter(context, _query);
    if (result != null && mounted) _update(() => _query = result);
  }

  Future<void> _statistics() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const DiningStatsPage()),
    );
  }

  Future<void> _sort() async {
    if (_locating) return;
    final sort = await showMenuActionSheet<RestaurantSort>(
      context: context,
      title: '餐厅排序',
      actions: (context) => [
        for (final sort in RestaurantSort.values)
          MenuSheetAction(
            icon: switch (sort) {
              RestaurantSort.recent => Icons.schedule,
              RestaurantSort.visits => Icons.bar_chart_outlined,
              RestaurantSort.price => Icons.receipt_long_outlined,
              RestaurantSort.nearest => Icons.location_on_outlined,
            },
            label: RestaurantQuery(sort: sort).sortLabel,
            selected: sort == _query.sort,
            onTap: () => Navigator.pop(context, sort),
          ),
      ],
    );
    if (sort == null || !mounted) return;
    if (sort == RestaurantSort.nearest) {
      setState(() => _locating = true);
      GeoPoint? origin;
      final success = await performAction(context, () async {
        origin = await locateForRestaurantSort(context);
      });
      if (!mounted) return;
      setState(() => _locating = false);
      if (!success || origin == null) return;
      _origin = origin;
    }
    _update(() => _query.sort = sort);
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = MenuScope.of(context).data.restaurants;
    final matching = restaurants.where(_query.matches).toList();
    final distances = <String, RestaurantDistance>{};
    if (_query.sort == RestaurantSort.nearest && _origin != null) {
      for (final restaurant in matching) {
        final nearest = nearestRestaurantAddress(
          restaurant.addressEntries.where(_query.matchesAddress),
          _origin!,
        );
        if (nearest != null) distances[restaurant.id] = nearest;
      }
    }
    final results = orderedRestaurants(
      matching,
      _query.sort,
      distances: distances,
    );
    final filterCount = [
      _query.hasCategory,
      _query.hasLocation,
      _query.start != null || _query.end != null,
      _query.alone || _query.companion.isNotEmpty,
      _query.hasPrice,
      _query.favorite,
    ].where((active) => active).length;
    final content = CustomScrollView(
      controller: _scroll,
      key: PageStorageKey(_standalone ? 'filtered-restaurants' : 'restaurants'),
      slivers: [
        if (!_standalone)
          SliverToBoxAdapter(
            child: Padding(
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
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _sort,
                      child: SizedBox(
                        height: 36,
                        child: IconTheme.merge(
                          data: IconThemeData(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const MenuIcon(Icons.sort, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _locating ? '定位中…' : _query.sortLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const RotatedBox(
                                quarterTurns: 1,
                                child: MenuIcon(Icons.chevron_right, size: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: _query.active
                  ? Icons.search_off
                  : Icons.storefront_outlined,
              title: _standalone || _query.active ? '没有符合条件的餐厅' : '收好值得再去的地方',
              message: _standalone || _query.active
                  ? '换个筛选条件，继续找找。'
                  : '点击右上角的＋添加餐厅，再记下吃过的菜和用餐感受。',
              actionLabel: _standalone
                  ? '调整筛选'
                  : _query.active
                  ? '查看全部餐厅'
                  : '添加餐厅',
              onAction: () {
                if (_standalone) {
                  _filter();
                } else if (_query.active) {
                  _update(() => _query = RestaurantQuery(sort: _query.sort));
                } else {
                  editRestaurant(context);
                }
              },
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              (_standalone ? 24 : 120) +
                  MediaQuery.viewPaddingOf(context).bottom,
            ),
            sliver: RestaurantCoverBatch(
              child: SliverRestaurantGrid(
                mainAxisSpacing: 10,
                itemCount: results.length,
                itemBuilder: (_, index) => RestaurantCard(
                  key: ValueKey(results[index].id),
                  restaurant: results[index],
                  showReview: true,
                  distance: distances[results[index].id],
                  showDistance: _query.sort == RestaurantSort.nearest,
                ),
              ),
            ),
          ),
      ],
    );
    if (_standalone) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            icon: const MenuIcon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Semantics(
            button: true,
            label: '餐厅，点击回到顶部',
            child: InkWell(
              onTap: scrollToTop,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: MenuTitleLine(
                  children: [
                    const Text('餐厅'),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '共 ${results.length} 家',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Tooltip(
              message: '排序：${_query.sortLabel}',
              child:
                  MediaQuery.sizeOf(context).width < 380 ||
                      MediaQuery.textScalerOf(context).scale(12) > 15
                  ? IconButton(
                      onPressed: _locating ? null : _sort,
                      icon: const MenuIcon(Icons.sort, size: 20),
                    )
                  : TextButton.icon(
                      onPressed: _locating ? null : _sort,
                      icon: const MenuIcon(Icons.sort, size: 18),
                      label: Text(
                        _locating
                            ? '定位中…'
                            : switch (_query.sort) {
                                RestaurantSort.recent => '最近到店',
                                RestaurantSort.visits => '消费次数',
                                RestaurantSort.price => '人均价格',
                                RestaurantSort.nearest => '离我最近',
                              },
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
            ),
            PageActionButton(
              icon: Icons.filter_alt_outlined,
              label: '筛选餐厅',
              badgeCount: filterCount,
              onPressed: _filter,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LibraryLayout.maxWidth,
              ),
              child: content,
            ),
          ),
        ),
      );
    }
    return MenuPage(
      maxWidth: LibraryLayout.maxWidth,
      title: '餐厅',
      onTitleTap: scrollToTop,
      actionsSpacing: 4,
      actions: [
        PageActionButton(
          icon: Icons.search,
          label: '搜索餐厅',
          onPressed: () =>
              pushSearchPage<void>(context, const RestaurantSearchPage()),
        ),
        PageActionButton(
          icon: Icons.filter_alt_outlined,
          label: '筛选餐厅',
          badgeCount: filterCount,
          onPressed: _filter,
        ),
        PageActionButton(
          icon: Icons.bar_chart_outlined,
          label: '用餐统计',
          onPressed: _statistics,
        ),
        IgnorePointer(
          ignoring: _creating,
          child: MenuPopupButton<String>(
            tooltip: '添加餐厅',
            buttonBuilder: (open) => PageAddButton(
              label: '添加餐厅，长按快捷创建',
              busy: _creating,
              onPressed: open,
              onLongPress: _quickCreate,
            ),
            itemBuilder: (_) => const [
              MenuPopupItem(
                value: 'standard',
                icon: Icons.edit_outlined,
                child: Text('正常创建'),
              ),
              MenuPopupItem(
                value: 'quick',
                icon: Icons.photo_library_outlined,
                child: Text('快捷创建'),
              ),
            ],
            onSelected: (value) {
              if (value == 'quick') {
                _quickCreate();
              } else {
                editRestaurant(context);
              }
            },
          ),
        ),
      ],
      child: content,
    );
  }
}
