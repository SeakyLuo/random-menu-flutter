import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/models.dart';
import '../../ui/search_match.dart';
import '../../ui/menu_icon.dart';
import 'restaurant_card.dart';
import 'restaurant_grid.dart';
import '../../ui/library_layout.dart';
import 'restaurant_search_cards.dart';
import 'restaurant_search_fields.dart';

class RestaurantSearchResults extends StatelessWidget {
  const RestaurantSearchResults({
    super.key,
    required this.matches,
    required this.query,
    required this.scope,
    required this.bottom,
    required this.controller,
    required this.onRestaurant,
    required this.onDish,
    required this.onContext,
    required this.onScope,
  });
  final RestaurantSearchMatches matches;
  final String query;
  final RestaurantSearchField scope;
  final double bottom;
  final ScrollController controller;
  final ValueChanged<Restaurant> onRestaurant;
  final ValueChanged<RestaurantDishHit> onDish;
  final ValueChanged<RestaurantSearchHit> onContext;
  final ValueChanged<RestaurantSearchField> onScope;

  Widget _restaurant(BuildContext context, RestaurantSearchHit hit) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: ValueKey(hit.restaurant.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RestaurantCard(
          restaurant: hit.restaurant,
          onOpen: () => onRestaurant(hit.restaurant),
          titleBuilder: (hasPhoto) => highlightSearchText(
            hit.restaurant.name,
            query,
            hasPhoto ? const Color(0xff83d8ac) : scheme.primary,
          ),
        ),
        if (hit.context case final text?)
          SearchMatchCaption(
            text: hit.visit != null || text == hit.restaurant.note
                ? '“${searchMatchExcerpt(text, query)}”'
                : searchMatchExcerpt(text, query),
            query: query,
            onTap: () => onContext(hit),
          ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    String label,
    int count,
    int preview,
    RestaurantSearchField field,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (count > preview)
              TextButton(
                onPressed: () => onScope(field),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('查看全部'),
                    SizedBox(width: 3),
                    MenuIcon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dishes(BuildContext context, int count) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final columns = LibraryLayout.recipeColumns(
        context,
        constraints.crossAxisExtent,
      );
      return SliverMasonryGrid.count(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 20,
        childCount: count,
        itemBuilder: (_, index) {
          final hit = matches.dishes[index];
          return SearchDishCard(
            key: ValueKey((hit.restaurant.id, hit.dish.name)),
            hit: hit,
            query: query,
            onOpen: () => onDish(hit),
          );
        },
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final all = scope == RestaurantSearchField.all;
    final slivers = <Widget>[];
    if (!all) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Text(
              '${matches.count(scope)} ${switch (scope) {
                RestaurantSearchField.dishes => '道菜',
                _ => '家餐厅',
              }}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    if ((all || scope == RestaurantSearchField.restaurants) &&
        matches.restaurants.isNotEmpty) {
      if (all) {
        slivers.add(
          _header(
            context,
            '餐厅',
            matches.restaurants.length,
            4,
            RestaurantSearchField.restaurants,
          ),
        );
      }
      slivers.add(
        SliverRestaurantGrid(
          itemCount: all
              ? math.min(4, matches.restaurants.length)
              : matches.restaurants.length,
          itemBuilder: (_, index) =>
              _restaurant(context, matches.restaurants[index]),
        ),
      );
      if (all) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 10)));
      }
    }
    if ((all || scope == RestaurantSearchField.dishes) &&
        matches.dishes.isNotEmpty) {
      if (all) {
        slivers.add(
          _header(
            context,
            '菜品',
            matches.dishes.length,
            8,
            RestaurantSearchField.dishes,
          ),
        );
      }
      slivers.add(
        _dishes(
          context,
          all ? math.min(8, matches.dishes.length) : matches.dishes.length,
        ),
      );
      if (all) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 28)));
      }
    }
    return CustomScrollView(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
  }
}
