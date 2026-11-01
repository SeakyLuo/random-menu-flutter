import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'recipe_detail_page.dart';
import 'recipe_editor.dart';
import 'recipe_photos.dart';
import 'recipe_search.dart';
import 'recipe_tags_page.dart';
import 'recipe_history_sheet.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});
  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final _search = TextEditingController();
  String? _tag;
  bool _favorites = false;
  RecipeSearchField _field = RecipeSearchField.all;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() => setState(() {
    _search.clear();
    _tag = null;
    _favorites = false;
    _field = RecipeSearchField.all;
  });

  Future<void> _rememberSearch() async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    final store = MenuScope.of(context);
    await performAction(
      context,
      () => store.update((data) {
        data.recipeSearchHistory.remove(query);
        data.recipeSearchHistory.insert(0, query);
      }),
    );
  }

  Future<void> _history() async {
    final query = await showRecipeSearchHistory(context);
    if (query == null || !mounted) return;
    setState(() {
      _search.text = query;
      _field = RecipeSearchField.all;
    });
  }

  Future<void> _resumeDraft() async {
    final store = MenuScope.of(context);
    final draft = store.data.recipeDraft!;
    final sourceId = store.data.recipeDraftSourceId;
    if (sourceId != null && !store.data.recipes.any((r) => r.id == sourceId)) {
      showToast(context, '原菜谱已删除，草稿将保存为新菜谱');
    }
    await editRecipe(context, recipe: draft, fromDraft: true);
  }

  Future<void> _deleteDraft() async {
    final store = MenuScope.of(context);
    if (!await confirmAction(
      context,
      title: '删除未完成的草稿？',
      message: '已保存的菜谱不会受影响。',
    )) {
      return;
    }
    if (!mounted) return;
    await performAction(
      context,
      () => store.update((data) {
        data.recipeDraft = null;
        data.recipeDraftSourceId = null;
      }),
      success: '草稿已删除',
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final recipes = data.recipes;
    final tags = orderedRecipeTags(data);
    final query = _search.text.trim();
    final scores = {
      if (query.isNotEmpty)
        for (final recipe in recipes)
          recipe.id: recipeSearchScore(recipe, query, _field),
    };
    final shown = recipes
        .where(
          (r) =>
              (!_favorites || r.favorite) &&
              (_tag == null || r.tags.contains(_tag)) &&
              (query.isEmpty || scores[r.id]! > 0),
        )
        .toList();
    if (query.isNotEmpty) {
      shown.sort((a, b) => scores[b.id]!.compareTo(scores[a.id]!));
    }
    return MenuPage(
      title: '菜谱',
      subtitle: '收好拿手菜，让每顿饭都有灵感',
      actions: [
        IconButton.filledTonal(
          tooltip: '添加菜谱',
          onPressed: () => editRecipe(context),
          icon: const MenuIcon(Icons.add),
        ),
        PopupMenuButton<String>(
          icon: const MenuIcon(Icons.more_horiz),
          tooltip: '菜谱管理',
          onSelected: (_) async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const RecipeTagsPage()),
            );
            if (!context.mounted) return;
            if (_tag != null &&
                !MenuScope.of(context).data.recipeTags.contains(_tag)) {
              setState(() => _tag = null);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'tags', child: Text('标签管理')),
          ],
        ),
      ],
      child: Column(
        children: [
          if (data.recipeDraft != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: const Text('未完成的菜谱'),
                  subtitle: Text(
                    data.recipeDraft!.name.isEmpty
                        ? '还未命名的草稿'
                        : data.recipeDraft!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: _resumeDraft,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _resumeDraft,
                        child: const Text('继续编辑'),
                      ),
                      IconButton(
                        tooltip: '删除草稿',
                        onPressed: _deleteDraft,
                        icon: const MenuIcon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: recipes.isEmpty
                ? EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: '从第一道拿手菜开始',
                    message: '记下做法、照片和标签，慢慢攒成自己的菜谱库。',
                    actionLabel: '添加菜谱',
                    onAction: () => editRecipe(context),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _rememberSearch(),
                          decoration: InputDecoration(
                            hintText: '搜索菜名、标签或备注',
                            prefixIcon: const MenuIcon(Icons.search),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_search.text.isNotEmpty)
                                  IconButton(
                                    tooltip: '清除搜索',
                                    onPressed: () => setState(_search.clear),
                                    icon: const MenuIcon(Icons.close),
                                  ),
                                IconButton(
                                  tooltip: '搜索历史',
                                  onPressed: _history,
                                  icon: const MenuIcon(Icons.history),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (query.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                          child: Row(
                            spacing: 8,
                            children: [
                              for (final field in RecipeSearchField.values)
                                ChoiceChip(
                                  label: Text(switch (field) {
                                    RecipeSearchField.all => '全部范围',
                                    RecipeSearchField.name => '菜名',
                                    RecipeSearchField.tags => '标签',
                                    RecipeSearchField.note => '备注',
                                  }),
                                  selected: _field == field,
                                  onSelected: (_) =>
                                      setState(() => _field = field),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          spacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('全部'),
                              selected: _tag == null && !_favorites,
                              onSelected: (_) => setState(() {
                                _tag = null;
                                _favorites = false;
                              }),
                            ),
                            FilterChip(
                              label: const Text('收藏'),
                              avatar: const MenuIcon(
                                Icons.favorite_border,
                                size: 17,
                              ),
                              selected: _favorites,
                              onSelected: (v) => setState(() => _favorites = v),
                            ),
                            for (final tag in tags)
                              FilterChip(
                                label: Text(tag),
                                selected: _tag == tag,
                                onSelected: (v) =>
                                    setState(() => _tag = v ? tag : null),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: shown.isEmpty
                            ? EmptyState(
                                icon: Icons.search_off_outlined,
                                title: '没有匹配的菜谱',
                                message: '试试其他关键词，或调整标签和收藏筛选。',
                                actionLabel: '清除筛选',
                                onAction: _clearFilters,
                              )
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  0,
                                  24,
                                  112 + MediaQuery.paddingOf(context).bottom,
                                ),
                                itemCount: shown.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, index) => _RecipeCard(
                                  recipe: shown[index],
                                  onOpen: _rememberSearch,
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.onOpen});
  final Recipe recipe;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onLongPress: () => editRecipe(context, recipe: recipe),
      onTap: () {
        onOpen();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RecipeDetailPage(recipeId: recipe.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 88,
                height: 88,
                child: recipe.imagePaths.isEmpty
                    ? ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: .4),
                        child: MenuIcon(
                          Icons.ramen_dining_outlined,
                          size: 34,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : RecipePhoto(path: recipe.imagePaths.first),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (recipe.favorite) ...[
                        const SizedBox(width: 8),
                        MenuIcon(
                          Icons.favorite,
                          size: 17,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      recipe.tags.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (recipe.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const MenuIcon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    ),
  );
}
