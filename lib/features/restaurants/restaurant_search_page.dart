import '../../ui/library_layout.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/retained_tab_view.dart';
import '../../ui/widgets.dart';
import 'restaurant_detail_page.dart';
import 'restaurant_dish_page.dart';
import 'visit_detail_page.dart';
import 'restaurant_editor.dart';
import 'restaurant_search_results.dart';
import 'restaurant_search_fields.dart';
import '../../ui/search_discovery.dart';
import '../../ui/search_field_bar.dart';
import '../../ui/menu_segmented.dart';

class RestaurantSearchPage extends StatefulWidget {
  const RestaurantSearchPage({super.key});
  @override
  State<RestaurantSearchPage> createState() => _RestaurantSearchPageState();
}

class _RestaurantSearchPageState extends State<RestaurantSearchPage> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _resultsScroll = {
    for (final scope in [
      RestaurantSearchField.all,
      RestaurantSearchField.restaurants,
      RestaurantSearchField.dishes,
    ])
      scope: ScrollController(keepScrollOffset: false),
  };
  RestaurantSearchField _scope = RestaurantSearchField.all;
  String _query = '';
  String _text = '';
  bool _managing = false;
  bool _historyBusy = false;
  bool _opening = false;

  static const _labels = {
    RestaurantSearchField.all: '全部',
    RestaurantSearchField.restaurants: '餐厅',
    RestaurantSearchField.dishes: '菜品',
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

  void _changeScope(RestaurantSearchField scope) {
    _focus.unfocus();
    setState(() => _scope = scope);
  }

  Future<bool> _remember(String term) async {
    if (term.isEmpty) return true;
    final store = MenuScope.of(context);
    final history = store.data.restaurantSearchHistory;
    if (history.isNotEmpty && history.first == term) return true;
    return performAction(
      context,
      () => store.update(MenuWriteScope.settings, (data) {
        data.restaurantSearchHistory.remove(term);
        data.restaurantSearchHistory.insert(0, term);
        if (data.restaurantSearchHistory.length > 20) {
          data.restaurantSearchHistory.removeRange(
            20,
            data.restaurantSearchHistory.length,
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

  Future<void> _openRestaurant(Restaurant restaurant) =>
      _openResult(RestaurantDetailPage(restaurantId: restaurant.id));

  Future<void> _openDish(RestaurantDishHit hit) => _openResult(
    RestaurantDishPage(
      restaurantId: hit.restaurant.id,
      name: hit.dish.name,
      sourceVisitId: hit.dish.history.first.visit.id,
      sourceItemIndex: hit.dish.history.first.index,
    ),
  );

  Future<void> _openContext(RestaurantSearchHit hit) => _openResult(
    hit.visit == null
        ? RestaurantDetailPage(restaurantId: hit.restaurant.id)
        : VisitDetailPage(
            restaurantId: hit.restaurant.id,
            visitId: hit.visit!.id,
          ),
  );

  Future<void> _openResult(Widget page) async {
    if (_opening) return;
    _opening = true;
    await _remember(_query);
    if (!mounted) return;
    _focus.unfocus();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    _opening = false;
  }

  Future<void> _removeHistory(String term) async {
    setState(() => _historyBusy = true);
    final store = MenuScope.of(context);
    await performAction(
      context,
      () => store.update(
        MenuWriteScope.settings,
        (data) => data.restaurantSearchHistory.remove(term),
      ),
    );
    if (!mounted) return;
    setState(() {
      _historyBusy = false;
      if (store.data.restaurantSearchHistory.isEmpty) _managing = false;
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
        (data) => data.restaurantSearchHistory.clear(),
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
    final searchClearance = SearchFieldBar.clearance(context);
    final term = _query.toLowerCase();
    final matches = searchRestaurantContents(data.restaurants, _query);
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
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: term.isEmpty
                            ? SearchDiscovery(
                                emptyTitle: '先收藏一家喜欢的餐厅',
                                emptyMessage: '添加餐厅后，就能查找餐厅、菜品和用餐评价。',
                                createLabel: '添加餐厅',
                                libraryEmpty: data.restaurants.isEmpty,
                                bottom: searchClearance,
                                history: data.restaurantSearchHistory,
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
                                  editRestaurant(context);
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
                                        matches,
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
                              hintText: '搜索餐厅、菜品、评价',
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

  Widget _resultsPage(
    MenuData data,
    RestaurantSearchMatches matches,
    RestaurantSearchField scope,
    double bottom,
  ) {
    if (data.restaurants.isEmpty) {
      return _emptyResults(context, libraryEmpty: true, scope: scope);
    }
    if (matches.count(scope) == 0) return _emptyResults(context, scope: scope);
    return RestaurantSearchResults(
      matches: matches,
      query: _query,
      scope: scope,
      bottom: bottom,
      controller: _resultsScroll[scope]!,
      onRestaurant: _openRestaurant,
      onDish: _openDish,
      onContext: _openContext,
      onScope: _changeScope,
    );
  }

  Widget _emptyResults(
    BuildContext context, {
    bool libraryEmpty = false,
    required RestaurantSearchField scope,
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
            libraryEmpty ? Icons.storefront : Icons.search_off,
            size: 40,
            color: scheme.onSurfaceVariant.withValues(alpha: .65),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          libraryEmpty
              ? '先收藏一家喜欢的餐厅'
              : '没有找到相关${scope == RestaurantSearchField.all ? '内容' : _labels[scope]}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          libraryEmpty
              ? '添加餐厅后，就能查找餐厅、菜品和用餐评价。'
              : scope == RestaurantSearchField.all
              ? '试试店名、菜品，或换个关键词。'
              : '没有包含“$_query”的${_labels[scope]}。',
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
                editRestaurant(context);
              },
              child: const Text('添加餐厅'),
            ),
          )
        else if (scope != RestaurantSearchField.all)
          Center(
            child: TextButton(
              onPressed: () => _changeScope(RestaurantSearchField.all),
              child: const Text('搜索全部'),
            ),
          ),
        if (!libraryEmpty && scope == RestaurantSearchField.all)
          Center(
            child: TextButton(onPressed: _rewrite, child: const Text('换个关键词')),
          ),
      ],
    );
  }
}
