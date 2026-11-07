import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_bottom_sheet.dart';
import '../../ui/menu_icon.dart';
import 'recipe_grid.dart';

Future<String?> showRecipeTagSheet(BuildContext context, String tag) =>
    showMenuBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) {
        final recipes = MenuScope.of(
          context,
        ).data.recipes.where((recipe) => recipe.tags.contains(tag)).toList();
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$tag · ${recipes.length} 道菜',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const MenuIcon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: recipes.isEmpty
                    ? const Center(child: Text('这个标签下还没有菜谱'))
                    : RecipeGrid(
                        recipes: recipes,
                        bottom: 16,
                        onOpen: (recipe) => Navigator.pop(context, recipe.id),
                      ),
              ),
            ],
          ),
        );
      },
    );
