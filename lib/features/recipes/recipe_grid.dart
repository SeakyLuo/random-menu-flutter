import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../random/random_recipe_card.dart';
import 'recipe_detail_page.dart';
import 'recipe_editor.dart';

class RecipeGrid extends StatelessWidget {
  const RecipeGrid({
    super.key,
    required this.recipes,
    this.bottom = 110,
    this.scrollKey,
    this.showCount = false,
    this.controller,
  });
  final List<Recipe> recipes;
  final double bottom;
  final PageStorageKey<String>? scrollKey;
  final bool showCount;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = constraints.maxWidth < 340 || scale > 1.8
          ? 1
          : constraints.maxWidth >= 600
          ? 3
          : 2;
      return CustomScrollView(
        key: scrollKey,
        controller: controller,
        slivers: [
          if (showCount)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Text(
                  '共 ${recipes.length} 道菜',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              bottom + MediaQuery.viewPaddingOf(context).bottom,
            ),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childCount: recipes.length,
              itemBuilder: (_, index) => RecipeLibraryCard(
                key: ValueKey(recipes[index].id),
                recipe: recipes[index],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class RecipeLibraryCard extends StatefulWidget {
  const RecipeLibraryCard({super.key, required this.recipe});
  final Recipe recipe;
  @override
  State<RecipeLibraryCard> createState() => _RecipeLibraryCardState();
}

class _RecipeLibraryCardState extends State<RecipeLibraryCard> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    return RandomRecipeCard(
      recipe: recipe,
      compact: true,
      onOpen: () => showRecipeDetail(context, recipe.id),
      onLongPress: () => editRecipe(context, recipe: recipe),
      onFavorite: _saving
          ? null
          : () async {
              setState(() => _saving = true);
              await performAction(
                context,
                () => MenuScope.of(context).update(
                  (d) =>
                      d.recipes.firstWhere((r) => r.id == recipe.id).favorite =
                          false,
                ),
                success: '已取消收藏',
              );
              if (mounted) setState(() => _saving = false);
            },
    );
  }
}
