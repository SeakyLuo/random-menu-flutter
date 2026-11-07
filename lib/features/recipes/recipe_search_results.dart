import 'package:flutter/material.dart';
import '../../core/models.dart';
import 'recipe_grid.dart';
import '../../ui/search_match.dart';

class RecipeSearchResults extends StatelessWidget {
  const RecipeSearchResults({
    super.key,
    required this.recipes,
    required this.query,
    required this.bottom,
    required this.controller,
    required this.onOpen,
  });

  final List<Recipe> recipes;
  final String query;
  final double bottom;
  final ScrollController controller;
  final ValueChanged<Recipe> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RecipeGrid(
      recipes: recipes,
      bottom: bottom,
      controller: controller,
      onOpen: onOpen,
      titleBuilder: (recipe) => highlightSearchText(
        recipe.name,
        query,
        recipe.imagePaths.isEmpty ? scheme.primary : const Color(0xff83d8ac),
      ),
      captionBuilder: (recipe) {
        if (!recipe.note.toLowerCase().contains(query.toLowerCase())) {
          return null;
        }
        return SearchMatchCaption(
          text: searchMatchExcerpt(recipe.note, query),
          query: query,
          onTap: () => onOpen(recipe),
        );
      },
    );
  }
}
