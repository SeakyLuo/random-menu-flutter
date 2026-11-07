import '../../ui/library_layout.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/library_widgets.dart';
import '../../ui/widgets.dart';
import 'recipe_editor.dart';
import 'recipe_grid.dart';
import 'recipe_search_page.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});
  @override
  State<RecipesPage> createState() => RecipesPageState();
}

class RecipesPageState extends State<RecipesPage>
    with TickerProviderStateMixin {
  TabController? _tabs;
  List<String> _tags = [];
  final _scrolls = <String?, ScrollController>{};

  void scrollToTop() {
    final tag = _tabs!.index == 0 ? null : _tags[_tabs!.index - 1];
    final controller = _scrolls[tag];
    if (controller != null) scrollMenuToTop(context, controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final counts = <String, int>{};
    for (final recipe in MenuScope.of(context).data.recipes) {
      for (final tag in recipe.tags.toSet()) {
        counts.update(tag, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    final tags = counts.keys.toList();
    final positions = {for (var i = 0; i < tags.length; i++) tags[i]: i};
    tags.sort((a, b) {
      final count = counts[b]!.compareTo(counts[a]!);
      return count != 0 ? count : positions[a]!.compareTo(positions[b]!);
    });
    if (_tabs == null || tags.join('\u0000') != _tags.join('\u0000')) {
      final selected = _tabs == null || _tabs!.index == 0
          ? null
          : _tags[_tabs!.index - 1];
      _tabs?.dispose();
      _tags = tags;
      _tabs = TabController(
        length: tags.length + 1,
        vsync: this,
        initialIndex: selected == null ? 0 : tags.indexOf(selected) + 1,
      );
    }
  }

  @override
  void dispose() {
    _tabs?.dispose();
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _categoryTab(String label) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final sorted = [...data.recipes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return MenuPage(
      maxWidth: LibraryLayout.maxWidth,
      title: '菜谱',
      compactHeader: true,
      actions: [
        PageActionButton(
          icon: Icons.search,
          label: '搜索菜谱',
          size: 40,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const RecipeSearchPage()),
          ),
        ),
        PageAddButton(label: '添加菜谱', onPressed: () => editRecipe(context)),
      ],
      child: Column(
        children: [
          if (_tags.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                labelPadding: const EdgeInsets.symmetric(horizontal: 11),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                ),
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(
                    width: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                dividerHeight: 0,
                tabs: [
                  _categoryTab('全部'),
                  for (final tag in _tags) _categoryTab(tag),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final tag in <String?>[null, ..._tags])
                  _RecipeTab(
                    key: ValueKey<String?>(tag),
                    child: Builder(
                      builder: (context) {
                        final recipes = sorted
                            .where((r) => tag == null || r.tags.contains(tag))
                            .toList();
                        return recipes.isEmpty
                            ? EmptyState(
                                icon: Icons.menu_book_outlined,
                                title: tag == null ? '从一道拿手菜开始' : '这个标签下还没有菜谱',
                                message: '点击右上角的＋添加菜谱，记下喜欢的味道。',
                                actionLabel: '添加菜谱',
                                onAction: () => editRecipe(context),
                              )
                            : RecipeGrid(
                                controller: _scrolls.putIfAbsent(
                                  tag,
                                  ScrollController.new,
                                ),
                                recipes: recipes,
                                showCount: true,
                                scrollKey: PageStorageKey(
                                  'recipes:${tag ?? 'all'}',
                                ),
                              );
                      },
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

class _RecipeTab extends StatefulWidget {
  const _RecipeTab({super.key, required this.child});

  final Widget child;

  @override
  State<_RecipeTab> createState() => _RecipeTabState();
}

class _RecipeTabState extends State<_RecipeTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
