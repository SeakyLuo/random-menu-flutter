import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import 'restaurant_filter.dart';
import 'restaurants_page.dart';

class RestaurantSearchPage extends StatefulWidget {
  const RestaurantSearchPage({super.key});
  @override
  State<RestaurantSearchPage> createState() => _RestaurantSearchPageState();
}

class _RestaurantSearchPageState extends State<RestaurantSearchPage> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _remember([String? text]) async {
    if (text != null) setState(() => _search.text = text);
    final value = _search.text.trim();
    if (value.isEmpty) return;
    await performAction(
      context,
      () => MenuScope.of(context).update((d) {
        d.restaurantSearchHistory.remove(value);
        d.restaurantSearchHistory.insert(0, value);
        if (d.restaurantSearchHistory.length > 20) {
          d.restaurantSearchHistory.removeRange(
            20,
            d.restaurantSearchHistory.length,
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final term = _search.text.trim().toLowerCase();
    final results = orderedRestaurants(
      data.restaurants
          .where(
            (r) => [
              r.name,
              r.category,
              r.note,
              ...r.addresses,
              ...r.foods.expand((d) => [d.name, d.note]),
              ...r.records.expand(
                (v) => [
                  v.address,
                  v.note,
                  ...v.items.expand((d) => [d.name, d.note]),
                ],
              ),
            ].any((value) => value.toLowerCase().contains(term)),
          )
          .toList(),
      RestaurantSort.recent,
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回餐厅',
                        onPressed: () => Navigator.pop(context),
                        icon: const MenuIcon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _remember(),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '搜索餐厅、菜系、地址或菜品',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(12),
                              child: MenuIcon(Icons.search, size: 20),
                            ),
                            suffixIcon: term.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: '清除搜索',
                                    onPressed: () => setState(_search.clear),
                                    icon: const MenuIcon(Icons.close, size: 18),
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      TextButton(onPressed: _remember, child: const Text('搜索')),
                    ],
                  ),
                ),
                if (term.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '找到 ${results.length} 家餐厅',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: term.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '搜索历史',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (data.restaurantSearchHistory.isNotEmpty)
                                  TextButton(
                                    onPressed: () => performAction(
                                      context,
                                      () => MenuScope.of(context).update(
                                        (d) =>
                                            d.restaurantSearchHistory.clear(),
                                      ),
                                    ),
                                    child: const Text('清空'),
                                  ),
                              ],
                            ),
                            if (data.restaurantSearchHistory.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 28),
                                child: Text('搜索过的关键词会留在这里'),
                              ),
                            for (final item in data.restaurantSearchHistory)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const MenuIcon(
                                  Icons.history,
                                  size: 21,
                                ),
                                title: Text(item),
                                onTap: () => _remember(item),
                                trailing: IconButton(
                                  tooltip: '删除搜索历史$item',
                                  icon: const MenuIcon(Icons.close, size: 19),
                                  onPressed: () => performAction(
                                    context,
                                    () => MenuScope.of(context).update(
                                      (d) => d.restaurantSearchHistory.remove(
                                        item,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : results.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off,
                          title: '没有找到相关餐厅',
                          message: '换个关键词，继续找找。',
                          actionLabel: '清除搜索',
                          onAction: () => setState(_search.clear),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: results.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 18),
                          itemBuilder: (_, index) => RestaurantCard(
                            key: ValueKey(results[index].id),
                            restaurant: results[index],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
