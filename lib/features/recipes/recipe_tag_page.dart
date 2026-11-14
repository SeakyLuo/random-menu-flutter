import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/library_layout.dart';
import '../../ui/widgets.dart';
import 'recipe_grid.dart';

class RecipeTagPage extends StatefulWidget {
  const RecipeTagPage({super.key, required this.tag});
  final String tag;

  @override
  State<RecipeTagPage> createState() => _RecipeTagPageState();
}

class _RecipeTagPageState extends State<RecipeTagPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipes = MenuScope.of(
      context,
    ).data.recipes.where((recipe) => recipe.tags.contains(widget.tag)).toList();
    return Scaffold(
      appBar: AppBar(
        title: MenuScrollTitle(
          controller: _scroll,
          child: MenuTitleLine(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(widget.tag)),
              const SizedBox(width: 10),
              Text(
                '${recipes.length} 道',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LibraryLayout.maxWidth),
          child: recipes.isEmpty
              ? EmptyState(
                  icon: Icons.edit_note,
                  title: '这个标签下还没有菜谱',
                  message: '给菜谱添加这个标签后，就会显示在这里。',
                  actionLabel: '返回标签管理',
                  onAction: () => Navigator.pop(context),
                )
              : RecipeGrid(recipes: recipes, controller: _scroll, bottom: 24),
        ),
      ),
    );
  }
}
