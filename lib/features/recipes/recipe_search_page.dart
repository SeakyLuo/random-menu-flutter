import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import 'recipe_editor.dart';
import 'recipe_grid.dart';
import 'recipe_search.dart';

class RecipeSearchPage extends StatefulWidget {
  const RecipeSearchPage({super.key});
  @override
  State<RecipeSearchPage> createState() => _RecipeSearchPageState();
}

class _RecipeSearchPageState extends State<RecipeSearchPage> {
  final _search = TextEditingController();
  RecipeSearchField _scope = RecipeSearchField.all;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _remember([String? text]) async {
    if (text != null) setState(() => _search.text = text);
    final term = _search.text.trim();
    if (term.isEmpty) return;
    await performAction(
      context,
      () => MenuScope.of(context).update((d) {
        d.recipeSearchHistory.remove(term);
        d.recipeSearchHistory.insert(0, term);
        if (d.recipeSearchHistory.length > 20) {
          d.recipeSearchHistory.removeRange(20, d.recipeSearchHistory.length);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final term = _search.text.trim().toLowerCase();
    final results = data.recipes.where((r) {
      final fields = switch (_scope) {
        RecipeSearchField.name => [r.name],
        RecipeSearchField.tags => r.tags,
        RecipeSearchField.note => [r.note],
        RecipeSearchField.all => [r.name, ...r.tags, r.note],
      };
      return fields.any((field) => field.toLowerCase().contains(term));
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '返回菜谱',
                        onPressed: () => Navigator.pop(context),
                        icon: const MenuIcon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _search,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _remember(),
                          decoration: InputDecoration(
                            hintText: '搜索菜名、标签或备注',
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
                Row(
                  children: [
                    for (final scope in RecipeSearchField.values)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _scope = scope),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 17),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: _scope == scope ? 3 : 1,
                                  color: _scope == scope
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                            child: Text(
                              switch (scope) {
                                RecipeSearchField.all => '全部',
                                RecipeSearchField.name => '菜名',
                                RecipeSearchField.tags => '标签',
                                RecipeSearchField.note => '备注',
                              },
                              style: TextStyle(
                                fontSize: 16,
                                color: _scope == scope
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (term.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '找到 ${results.length} 道菜',
                        style: TextStyle(
                          fontSize: 12,
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
                                if (data.recipeSearchHistory.isNotEmpty)
                                  TextButton(
                                    onPressed: () => performAction(
                                      context,
                                      () => MenuScope.of(context).update(
                                        (d) => d.recipeSearchHistory.clear(),
                                      ),
                                    ),
                                    child: const Text('清空'),
                                  ),
                              ],
                            ),
                            if (data.recipeSearchHistory.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 28),
                                child: Text('搜索过的关键词会留在这里'),
                              ),
                            for (final item in data.recipeSearchHistory)
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
                                      (d) => d.recipeSearchHistory.remove(item),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : results.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off,
                          title: '没有找到相关菜谱',
                          message: '换个关键词，或记下这道想吃的菜。',
                          actionLabel: '添加菜谱',
                          onAction: () => editRecipe(context),
                        )
                      : RecipeGrid(recipes: results, bottom: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
