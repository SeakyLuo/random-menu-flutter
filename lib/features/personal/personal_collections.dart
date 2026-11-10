import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import '../../ui/library_widgets.dart';
import '../../ui/library_layout.dart';
import '../restaurants/restaurant_grid.dart';
import '../recipes/recipe_grid.dart';
import '../restaurants/restaurants_page.dart';
import '../restaurants/restaurant_filter.dart';
export 'personal_list_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.onBrowseRecipes,
    required this.onBrowseRestaurants,
  });
  final VoidCallback onBrowseRecipes;
  final VoidCallback onBrowseRestaurants;
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _scrolls = [ScrollController(), ScrollController()];
  @override
  void dispose() {
    for (final scroll in _scrolls) {
      scroll.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final recipes = data.recipes.where((r) => r.favorite).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final restaurants = orderedRestaurants(
      data.restaurants.where((r) => r.favorite).toList(),
      RestaurantSort.recent,
    );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          toolbarHeight: 48,
          title: Builder(
            builder: (context) => MenuScrollTitle(
              onTap: () => scrollMenuToTop(
                context,
                _scrolls[DefaultTabController.of(context).index],
              ),
              child: const Text('我的收藏'),
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: LibraryLayout.maxWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 16, 10),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    padding: EdgeInsets.zero,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicator: ShapeDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .12),
                      shape: const StadiumBorder(),
                    ),
                    automaticIndicatorColorAdjustment: false,
                    splashBorderRadius: BorderRadius.circular(24),
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: [
                      _FavoriteTab(label: '菜谱', count: recipes.length),
                      _FavoriteTab(label: '餐厅', count: restaurants.length),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      recipes.isEmpty
                          ? EmptyState(
                              icon: Icons.favorite_border,
                              title: '还没有收藏的菜谱',
                              message: '看看其他菜谱，找到这一餐想吃的味道。',
                              actionLabel: '浏览全部菜谱',
                              onAction: () {
                                Navigator.pop(context);
                                widget.onBrowseRecipes();
                              },
                            )
                          : RecipeGrid(
                              controller: _scrolls[0],
                              recipes: recipes,
                              bottom: 24,
                              scrollKey: const PageStorageKey(
                                'favorite-recipes',
                              ),
                            ),
                      restaurants.isEmpty
                          ? EmptyState(
                              icon: Icons.favorite_border,
                              title: '还没有收藏的餐厅',
                              message: '浏览餐厅，把喜欢的地方留下来。',
                              actionLabel: '浏览全部餐厅',
                              onAction: () {
                                Navigator.pop(context);
                                widget.onBrowseRestaurants();
                              },
                            )
                          : CustomScrollView(
                              controller: _scrolls[1],
                              key: const PageStorageKey('favorite-restaurants'),
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    24,
                                  ),
                                  sliver: SliverRestaurantGrid(
                                    itemCount: restaurants.length,
                                    itemBuilder: (_, index) => RestaurantCard(
                                      key: ValueKey(restaurants[index].id),
                                      restaurant: restaurants[index],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
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

class _FavoriteTab extends StatelessWidget {
  const _FavoriteTab({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Tab(
    height: 38,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    ),
  );
}
