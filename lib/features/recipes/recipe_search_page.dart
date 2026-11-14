import '../../ui/library_layout.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/retained_tab_view.dart';
import '../../ui/widgets.dart';
import 'recipe_detail_page.dart';
import 'recipe_editor.dart';
import 'recipe_search_results.dart';
import 'recipe_search.dart';
import '../../ui/search_discovery.dart';
import '../../ui/search_field_bar.dart';
import '../../ui/menu_segmented.dart';

class RecipeSearchPage extends StatefulWidget {
  const RecipeSearchPage({super.key});
  @override
  State<RecipeSearchPage> createState() => _RecipeSearchPageState();
}

class _RecipeSearchPageState extends State<RecipeSearchPage> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _resultsScroll = {
    for (final scope in [
      RecipeSearchField.all,
      RecipeSearchField.name,
      RecipeSearchField.note,
    ])
      scope: ScrollController(keepScrollOffset: false),
  };
  RecipeSearchField _scope = RecipeSearchField.all;
  String _query = '';
  String _text = '';
  bool _managing = false;
  bool _historyBusy = false;
  bool _opening = false;

  static const _labels = {
    RecipeSearchField.all: '全部',
    RecipeSearchField.name: '菜名',
    RecipeSearchField.note: '备注',
  };

  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    for (final controller in _resultsScroll.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetResults() {
    for (final controller in _resultsScroll.values) {
      if (controller.hasClients) controller.jumpTo(0);
    }
  }

  void _changed() {
    if (!_search.value.composing.isCollapsed) return;
    final text = _search.text;
    if (text == _text) return;
    final query = text.trim();
    final changed = query != _query;
    setState(() {
      _text = text;
      _query = query;
      _managing = false;
    });
    if (changed) _resetResults();
  }

  void _changeScope(RecipeSearchField scope) {
    _focus.unfocus();
    setState(() => _scope = scope);
  }

  Future<bool> _remember(String term) async {
    if (term.isEmpty) return true;
    final store = MenuScope.of(context);
    final history = store.data.recipeSearchHistory;
    if (history.isNotEmpty && history.first == term) return true;
    return performAction(
      context,
      () => store.update(MenuWriteScope.settings, (data) {
        data.recipeSearchHistory.remove(term);
        data.recipeSearchHistory.insert(0, term);
        if (data.recipeSearchHistory.length > 20) {
          data.recipeSearchHistory.removeRange(
            20,
            data.recipeSearchHistory.length,
          );
        }
      }),
    );
  }

  Future<void> _useKeyword(String term) async {
    _search.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    setState(() {
      _query = term;
      _managing = false;
    });
    _resetResults();
    _focus.unfocus();
    await _remember(term);
  }

  Future<void> _submit() async {
    _changed();
    _focus.unfocus();
    await _remember(_search.text.trim());
  }

  Future<void> _openRecipe(Recipe recipe) async {
    if (_opening) return;
    _opening = true;
    await _remember(_query);
    if (!mounted) return;
    _focus.unfocus();
    await showRecipeDetail(context, recipe.id);
    _opening = false;
  }

  Future<void> _removeHistory(String term) async {
    setState(() => _historyBusy = true);
    final store = MenuScope.of(context);
    await performAction(
      context,
      () => store.update(
        MenuWriteScope.settings,
        (data) => data.recipeSearchHistory.remove(term),
      ),
    );
    if (!mounted) return;
    setState(() {
      _historyBusy = false;
      if (store.data.recipeSearchHistory.isEmpty) _managing = false;
    });
  }

  Future<void> _clearHistory() async {
    if (!await confirmAction(
      context,
      title: '清空搜索历史？',
      message: '清空后无法恢复。',
      confirmLabel: '清空',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _historyBusy = true);
    final saved = await performAction(
      context,
      () => MenuScope.of(context).update(
        MenuWriteScope.settings,
        (data) => data.recipeSearchHistory.clear(),
      ),
      success: '搜索历史已清空',
    );
    if (!mounted) return;
    setState(() {
      _historyBusy = false;
      if (saved) _managing = false;
    });
  }

  void _rewrite() {
    _search.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _search.text.length,
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final scheme = Theme.of(context).colorScheme;
    final searchClearance = SearchFieldBar.clearance(context);
    final term = _query.toLowerCase();
    final results = _resultsFor(data, _scope);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: LibraryLayout.maxWidth),
            child: Column(
              children: [
                if (term.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: MenuSegmented(
                          labels: _labels,
                          selected: _scope,
                          onChanged: _changeScope,
                        ),
                      ),
                    ),
                  ),
                if (results.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${results.length} 道菜',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: term.isEmpty
                            ? SearchDiscovery(
                                emptyTitle: '先收下一道喜欢的菜',
                                emptyMessage: '添加菜谱后，就能按菜名和备注查找。',
                                createLabel: '添加菜谱',
                                libraryEmpty: data.recipes.isEmpty,
                                bottom: searchClearance,
                                history: data.recipeSearchHistory,
                                managing: _managing,
                                busy: _historyBusy,
                                onManage: () {
                                  _focus.unfocus();
                                  setState(() => _managing = !_managing);
                                },
                                onHistory: _useKeyword,
                                onRemove: _removeHistory,
                                onClear: _clearHistory,
                                onCreate: () {
                                  _focus.unfocus();
                                  editRecipe(context);
                                },
                              )
                            : NotificationListener<ScrollStartNotification>(
                                onNotification: (notification) {
                                  if (notification.dragDetails != null) {
                                    _focus.unfocus();
                                  }
                                  return false;
                                },
                                child: RetainedTabView(
                                  index: _labels.keys.toList().indexOf(_scope),
                                  onChanged: (index) => _changeScope(
                                    _labels.keys.elementAt(index),
                                  ),
                                  children: [
                                    for (final scope in _labels.keys)
                                      _resultsPage(
                                        data,
                                        scope,
                                        searchClearance,
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 16,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: SearchFieldBar(
                              onClose: () => Navigator.pop(context),
                              hintText: '搜索菜名、备注',
                              controller: _search,
                              focusNode: _focus,
                              onSubmitted: (_) => _submit(),
                            ),
                          ),
                        ),
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

  List<Recipe> _resultsFor(MenuData data, RecipeSearchField scope) {
    final term = _query.toLowerCase();
    if (term.isEmpty) return [];
    final results = data.recipes.where((recipe) {
      return (scope != RecipeSearchField.note &&
              recipe.name.toLowerCase().contains(term)) ||
          (scope != RecipeSearchField.name &&
              recipe.note.toLowerCase().contains(term));
    }).toList();
    final scores = {
      for (final recipe in results)
        recipe.id: recipeSearchScore(recipe, _query, scope),
    };
    final positions = {for (final (i, recipe) in results.indexed) recipe.id: i};
    results.sort((a, b) {
      final relevance = scores[b.id]!.compareTo(scores[a.id]!);
      if (relevance != 0) return relevance;
      final added = b.createdAt.compareTo(a.createdAt);
      return added != 0 ? added : positions[a.id]!.compareTo(positions[b.id]!);
    });
    return results;
  }

  Widget _resultsPage(MenuData data, RecipeSearchField scope, double bottom) {
    if (data.recipes.isEmpty) {
      return _emptyResults(context, libraryEmpty: true, scope: scope);
    }
    final results = _resultsFor(data, scope);
    if (results.isEmpty) return _emptyResults(context, scope: scope);
    return RecipeSearchResults(
      recipes: results,
      query: _query,
      bottom: bottom,
      controller: _resultsScroll[scope]!,
      onOpen: _openRecipe,
    );
  }

  Widget _emptyResults(
    BuildContext context, {
    bool libraryEmpty = false,
    required RecipeSearchField scope,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        28,
        40,
        28,
        SearchFieldBar.clearance(context),
      ),
      children: [
        Center(
          child: MenuIcon(
            libraryEmpty ? Icons.edit_note : Icons.search_off,
            size: 40,
            color: scheme.onSurfaceVariant.withValues(alpha: .65),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          libraryEmpty ? '先收下一道喜欢的菜' : '没有找到相关菜谱',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          libraryEmpty
              ? '添加菜谱后，就能按菜名和备注查找。'
              : scope == RecipeSearchField.all
              ? '试试更短的关键词。'
              : '没有${_labels[scope]}包含“$_query”的菜谱。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (libraryEmpty)
          Center(
            child: FilledButton(
              onPressed: () {
                _focus.unfocus();
                editRecipe(context);
              },
              child: const Text('添加菜谱'),
            ),
          )
        else if (scope != RecipeSearchField.all)
          Center(
            child: TextButton(
              onPressed: () => _changeScope(RecipeSearchField.all),
              child: const Text('搜索全部'),
            ),
          ),
        if (!libraryEmpty && scope == RecipeSearchField.all)
          Center(
            child: TextButton(onPressed: _rewrite, child: const Text('换个关键词')),
          ),
      ],
    );
  }
}
