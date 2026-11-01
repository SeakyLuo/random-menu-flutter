import '../../ui/menu_icon.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../photo_import/photo_import_page.dart';
import 'companion_stats_page.dart';
import 'restaurant_detail_page.dart';
import 'restaurant_editor.dart';
import 'restaurant_filter.dart';
import 'restaurant_history_sheet.dart';
import 'restaurant_search.dart';
export 'restaurant_editor.dart' show editRestaurant;

class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({super.key});
  @override
  State<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  final searchController = TextEditingController();
  String category = '';
  RestaurantQuery query = RestaurantQuery();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> filter() async {
    final selected = await editRestaurantFilter(context, query);
    if (selected != null && mounted) setState(() => query = selected);
  }

  Future<void> rememberSearch() async {
    final keyword = searchController.text.trim();
    if (keyword.isEmpty) return;
    final store = MenuScope.of(context);
    await performAction(
      context,
      () => store.update((data) {
        data.restaurantSearchHistory.remove(keyword);
        data.restaurantSearchHistory.insert(0, keyword);
      }),
    );
  }

  Future<void> history() async {
    final keyword = await showRestaurantSearchHistory(context);
    if (keyword == null || !mounted) return;
    setState(() => searchController.text = keyword);
    await rememberSearch();
  }

  void reset() => setState(() {
    searchController.clear();
    category = '';
    query = RestaurantQuery(sort: query.sort);
  });
  @override
  Widget build(BuildContext context) {
    final restaurants = MenuScope.of(context).data.restaurants;
    final categories =
        restaurants
            .map((r) => r.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final activeCategory = categories.contains(category) ? category : '';
    final search = searchController.text.trim().toLowerCase();
    final scores = {
      if (search.isNotEmpty)
        for (final r in restaurants) r.id: restaurantSearchScore(r, search),
    };
    final results = restaurants.reversed
        .where(
          (r) =>
              (activeCategory.isEmpty || r.category == activeCategory) &&
              query.matches(r) &&
              (search.isEmpty || scores[r.id]! > 0),
        )
        .toList();
    final lastVisits = {
      for (final r in results)
        r.id: r.records.fold(
          0,
          (latest, v) => v.date.millisecondsSinceEpoch > latest
              ? v.date.millisecondsSinceEpoch
              : latest,
        ),
    };
    switch (query.sort) {
      case RestaurantSort.recent:
        results.sort(
          (a, b) => search.isNotEmpty
              ? scores[b.id]!.compareTo(scores[a.id]!)
              : lastVisits[b.id]!.compareTo(lastVisits[a.id]!),
        );
      case RestaurantSort.visits:
        results.sort((a, b) => b.records.length.compareTo(a.records.length));
      case RestaurantSort.price:
        results.sort((a, b) => b.averageCost.compareTo(a.averageCost));
    }
    return MenuPage(
      title: '餐厅',
      subtitle: '把好吃的地方，慢慢收集起来',
      actions: [
        IconButton(
          tooltip: '筛选餐厅',
          onPressed: filter,
          icon: MenuIcon(
            query.active ? Icons.filter_alt : Icons.filter_alt_outlined,
            color: query.active ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        PopupMenuButton<String>(
          icon: const MenuIcon(Icons.more_horiz),
          tooltip: '排序与统计',
          onSelected: (value) {
            switch (value) {
              case 'recent':
                setState(() => query.sort = RestaurantSort.recent);
              case 'visits':
                setState(() => query.sort = RestaurantSort.visits);
              case 'price':
                setState(() => query.sort = RestaurantSort.price);
              case 'companions':
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const CompanionStatsPage(),
                  ),
                );
            }
          },
          itemBuilder: (_) => [
            for (final sort in RestaurantSort.values)
              PopupMenuItem(
                value: sort.name,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(switch (sort) {
                        RestaurantSort.recent => '最近用餐',
                        RestaurantSort.visits => '用餐次数最多',
                        RestaurantSort.price => '人均消费最高',
                      }),
                    ),
                    if (query.sort == sort)
                      const MenuIcon(Icons.check, size: 18),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'companions', child: Text('同行人统计')),
          ],
        ),
        PopupMenuButton<String>(
          tooltip: '添加餐厅',
          icon: const MenuIcon(Icons.add),
          onSelected: (value) {
            if (value == 'manual') {
              editRestaurant(context);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PhotoImportPage(),
                ),
              );
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'manual', child: Text('手动添加餐厅')),
            PopupMenuItem(value: 'photos', child: Text('从照片创建餐厅')),
          ],
        ),
      ],
      child: restaurants.isEmpty
          ? EmptyState(
              icon: Icons.storefront_outlined,
              title: '从一家喜欢的餐厅开始',
              message: '收藏店铺、记录每一次用餐，\n下次想吃什么就有了答案。',
              actionLabel: '添加餐厅',
              onAction: () => editRestaurant(context),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => rememberSearch(),
                    decoration: InputDecoration(
                      hintText: '搜索餐厅、菜品、地址或备注',
                      prefixIcon: const MenuIcon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (searchController.text.isNotEmpty)
                            IconButton(
                              tooltip: '清除搜索',
                              onPressed: () => setState(searchController.clear),
                              icon: const MenuIcon(Icons.close),
                            ),
                          IconButton(
                            tooltip: '搜索历史',
                            onPressed: history,
                            icon: const MenuIcon(Icons.history),
                          ),
                        ],
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (categories.isNotEmpty)
                  SizedBox(
                    height: 62,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final c in ['', ...categories])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c.isEmpty ? '全部' : c),
                              selected: activeCategory == c,
                              onSelected: (_) => setState(() => category = c),
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${results.length} 家餐厅 · ${search.isNotEmpty && query.sort == RestaurantSort.recent ? '匹配程度' : query.sortLabel}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (query.active)
                        TextButton(
                          onPressed: () => setState(
                            () => query = RestaurantQuery(sort: query.sort),
                          ),
                          child: const Text('清除筛选'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: results.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off,
                          title: '没有找到餐厅',
                          message: '试试其他关键词，或清除筛选条件。',
                          actionLabel: '清除搜索和筛选',
                          onAction: reset,
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            12,
                            24,
                            112 + MediaQuery.paddingOf(context).bottom,
                          ),
                          itemCount: results.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => RestaurantCard(
                            restaurant: results[index],
                            query: query,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.restaurant, this.query});
  final Restaurant restaurant;
  final RestaurantQuery? query;
  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final previews = r.foods
        .where((d) => d.imagePaths.isNotEmpty)
        .take(4)
        .toList();
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                RestaurantDetailPage(restaurantId: r.id, query: query),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  MenuIcon(
                    r.favorite ? Icons.favorite : Icons.chevron_right,
                    color: r.favorite
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                [
                  if (r.category.isNotEmpty) r.category,
                  '${r.records.length} 次用餐',
                  if (r.averageCost > 0) '人均 ¥${money(r.averageCost)}',
                ].join(' · '),
              ),
              if (r.addresses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    r.addresses.join('\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (r.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    r.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (previews.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final dish in previews)
                        SizedBox(
                          width: 64,
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(dish.imagePaths.first),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) =>
                                      const SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: MenuIcon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dish.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
