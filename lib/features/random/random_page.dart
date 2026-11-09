import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/library_widgets.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../../ui/rolling_count.dart';
import '../recipes/recipe_detail_page.dart';
import '../recipes/recipe_editor.dart';
import 'random_deck.dart';
import 'random_panels.dart';
import 'random_recipe_card.dart';

class RandomPage extends StatefulWidget {
  const RandomPage({
    super.key,
    required this.onOpenRecipes,
    required this.onBusy,
  });
  final VoidCallback onOpenRecipes;
  final ValueChanged<bool> onBusy;
  @override
  State<RandomPage> createState() => _RandomPageState();
}

class _RandomPageState extends State<RandomPage> {
  final _seen = <String>{};
  final _preferred = <String>{};
  final _excluded = <String>{};
  final _queue = <String>[];
  final _deck = GlobalKey<RandomDeckState>();
  final _target = GlobalKey();
  final _rail = ScrollController();
  final _arrival = ValueNotifier(0.0);
  final _random = Random();
  bool _busy = false;
  List<Recipe> _heldMenu = [];
  List<Recipe> _heldCards = [];

  List<Recipe> _matching(MenuData data) => data.recipes
      .where(
        (r) =>
            (_preferred.isEmpty || r.tags.any(_preferred.contains)) &&
            !r.tags.any(_excluded.contains),
      )
      .toList();
  List<Recipe> _available(MenuData data) => _matching(data)
      .where((r) => r.hiddenRounds == 0 && !data.selectedMenu.contains(r.id))
      .toList();
  void _reconcile(MenuData data) {
    final ids = _available(data).map((r) => r.id).toSet();
    _queue.removeWhere((id) => !ids.contains(id) || _seen.contains(id));
    final queued = _queue.toSet();
    final added =
        ids.where((id) => !queued.contains(id) && !_seen.contains(id)).toList()
          ..shuffle(_random);
    _queue.addAll(added);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_busy) return;
    final data = MenuScope.of(context).data;
    final tags = data.recipes.expand((r) => r.tags).toSet();
    _preferred.retainAll(tags);
    _excluded.retainAll(tags);
    _reconcile(data);
  }

  @override
  void dispose() {
    _rail.dispose();
    _arrival.dispose();
    super.dispose();
  }

  List<Recipe> _menu(MenuData data) {
    final recipes = {for (final r in data.recipes) r.id: r};
    return data.selectedMenu.reversed.map((id) => recipes[id]!).toList();
  }

  List<Recipe> _cards(MenuData data) {
    final recipes = {for (final r in data.recipes) r.id: r};
    // Keep one covered candidate mounted before it becomes the third card.
    return _queue.take(4).map((id) => recipes[id]!).toList();
  }

  void _lock(bool busy) {
    if (busy) {
      final data = MenuScope.of(context).data;
      _heldMenu = _menu(data);
      _heldCards = _cards(data);
    }
    setState(() {
      _busy = busy;
    });
    widget.onBusy(busy);
  }

  Future<bool> _pick(PickAction action, Future<void> animation) async {
    final store = MenuScope.of(context);
    final current = _queue.first;
    var railAnimation = Future<void>.value();
    if (action == PickAction.add && _rail.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _rail.jumpTo(0);
      } else {
        railAnimation = _rail.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
    final handoff = Future.wait([animation, railAnimation]);
    Object? failure;
    final saved = action == PickAction.skip
        ? Future.value(true)
        : () async {
            try {
              await store.update(
                action == PickAction.add
                    ? MenuWriteScope.settings
                    : MenuWriteScope.recipesAll,
                (data) {
                  if (action == PickAction.add) {
                    data.selectedMenu.add(current);
                  } else {
                    data.selectedMenu.clear();
                    for (final r in data.recipes) {
                      if (r.hiddenRounds > 0) r.hiddenRounds--;
                    }
                  }
                },
                publishAfter: handoff,
              );
              return true;
            } catch (error, stack) {
              failure = error;
              debugPrint('Menu action failed: $error\n$stack');
              return false;
            }
          }();
    await handoff;
    final success = await saved;
    if (!mounted) return false;
    if (success) {
      setState(() {
        if (action == PickAction.reset) {
          _seen.clear();
          _queue.clear();
        } else {
          _seen.add(current);
          _queue.remove(current);
        }
        _reconcile(store.data);
        _heldMenu = _menu(store.data);
        _heldCards = _cards(store.data);
        _arrival.value = 0;
      });
    } else if (failure != null) {
      // Report after the deck has returned to its resting position.
      Future<void>.delayed(
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 310),
        () {
          if (mounted) showToast(context, '操作未完成，请重试');
        },
      );
    }
    return success;
  }

  Future<void> _round({
    bool clear = false,
    bool restore = false,
    bool decrement = true,
  }) async {
    final store = MenuScope.of(context);
    _lock(true);
    final saved = await performAction(
      context,
      () => store.update(MenuWriteScope.recipesAll, (data) {
        if (clear) data.selectedMenu.clear();
        for (final r in data.recipes) {
          if (restore) {
            r.hiddenRounds = 0;
          } else if (decrement && r.hiddenRounds > 0) {
            r.hiddenRounds--;
          }
        }
      }),
    );
    if (!mounted) return;
    if (saved) {
      setState(() {
        _seen.clear();
        _queue.clear();
        _reconcile(store.data);
      });
    }
    _lock(false);
  }

  Future<void> _reset() async {
    final data = MenuScope.of(context).data;
    if (data.selectedMenu.isNotEmpty &&
        !await confirmAction(
          context,
          title: '重置菜单？',
          message: '将清空菜单并重新开始挑选，菜谱和收藏会保留。',
          confirmLabel: '确认重置',
        )) {
      return;
    }
    if (!mounted) return;
    if (_queue.isEmpty) {
      await _round(clear: true);
    } else {
      await _deck.currentState!.choose(PickAction.reset);
    }
  }

  Future<void> _filter() async {
    final result = await showHomeSheet<(Set<String>, Set<String>)>(
      context,
      fitContent: true,
      child: RandomFilterSheet(
        header: const HomeSheetHeader('筛选菜谱'),
        preferred: _preferred,
        excluded: _excluded,
        onRecipes: widget.onOpenRecipes,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _preferred
        ..clear()
        ..addAll(result.$1);
      _excluded
        ..clear()
        ..addAll(result.$2);
      _seen.clear();
      _queue.clear();
      _reconcile(MenuScope.of(context).data);
    });
  }

  Future<void> _openMenu() async {
    final before = {...MenuScope.of(context).data.selectedMenu};
    await showHomeSheet<void>(
      context,
      child: RandomMenuSheet(
        onRemoved: (ids) {
          setState(() {
            _seen.removeAll(ids);
            _reconcile(MenuScope.of(context).data);
          });
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      _seen.removeAll(
        before.difference(MenuScope.of(context).data.selectedMenu.toSet()),
      );
      _reconcile(MenuScope.of(context).data);
    });
  }

  void _open(Recipe recipe) => showRecipeDetail(context, recipe.id);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final data = MenuScope.of(context).data;
    final cards = _busy ? _heldCards : _cards(data);
    final filterCount = _preferred.length + _excluded.length;
    return ColoredBox(
      color: dark ? const Color(0xff111c17) : const Color(0xfff4f9f5),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final minHeight = scale > 1.3 ? 760.0 * scale / 1.3 : 600.0;
                final height = max(constraints.maxHeight, minHeight);
                return SingleChildScrollView(
                  child: SizedBox(
                    height: height,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MenuAppBar(
                            title: '随机菜单',
                            actions: [
                              PageActionButton(
                                icon: Icons.filter_alt_outlined,
                                label: '筛选菜谱',
                                badgeCount: filterCount,
                                onPressed: _busy ? null : _filter,
                              ),
                            ],
                          ),
                          _overview(context, _busy ? _heldMenu : _menu(data)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: cards.isNotEmpty
                                ? RandomDeck(
                                    key: _deck,
                                    enabled: !_busy,
                                    recipes: cards,
                                    target: _target,
                                    onAction: _pick,
                                    onBusy: _lock,
                                    onProgress: (value) =>
                                        _arrival.value = value,
                                    onOpen: () => _open(cards.first),
                                    onFavorite: () async {
                                      _lock(true);
                                      await performAction(
                                        context,
                                        () => MenuScope.of(context).update(
                                          MenuWriteScope.settings,
                                          (d) =>
                                              d.recipes
                                                      .firstWhere(
                                                        (r) =>
                                                            r.id ==
                                                            cards.first.id,
                                                      )
                                                      .favorite =
                                                  false,
                                        ),
                                      );
                                      if (mounted) _lock(false);
                                    },
                                  )
                                : _empty(context, data),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _overview(BuildContext context, List<Recipe> menu) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _busy ? null : _openMenu,
    child: Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .04),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _busy ? null : _openMenu,
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            menu.isEmpty ? '菜单' : '菜单 · ',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Visibility(
                            visible: menu.isNotEmpty,
                            maintainState: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RollingCount(
                                  value: menu.length,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  '道',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const MenuIcon(Icons.chevron_right, size: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(left: 16),
                  minimumSize: const Size(44, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  disabledForegroundColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
                onPressed: _busy || MenuScope.of(context).data.recipes.isEmpty
                    ? null
                    : _reset,
                child: const Text('重置', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = min(64.0, (constraints.maxWidth - 32) / 5);
              return SizedBox(
                height: size,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: SizedBox(key: _target, width: size, height: size),
                    ),
                    if (menu.isEmpty)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            '把想吃的菜拖到这里',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned.fill(
                        child: ClipRect(
                          child: ValueListenableBuilder<double>(
                            valueListenable: _arrival,
                            builder: (context, progress, child) =>
                                Transform.translate(
                                  offset: Offset((size + 8) * progress, 0),
                                  child: child,
                                ),
                            child: ListView.separated(
                              controller: _rail,
                              scrollDirection: Axis.horizontal,
                              physics: _busy
                                  ? const NeverScrollableScrollPhysics()
                                  : null,
                              itemCount: menu.length,
                              findItemIndexCallback: (key) {
                                final id = (key as ValueKey<String>).value;
                                final index = menu.indexWhere(
                                  (recipe) => recipe.id == id,
                                );
                                return index == -1 ? null : index;
                              },
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) => SizedBox(
                                key: ValueKey(menu[index].id),
                                width: size,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Semantics(
                                    button: true,
                                    label: '打开菜单，${menu[index].name}',
                                    child: GestureDetector(
                                      onTap: _busy ? null : _openMenu,
                                      child: RecipeCover(recipe: menu[index]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _empty(BuildContext context, MenuData data) {
    final matching = _matching(data);
    final available = _available(data);
    final hidden = matching.any(
      (r) => r.hiddenRounds > 0 && !data.selectedMenu.contains(r.id),
    );
    final noRecipes = data.recipes.isEmpty;
    final noMatch = matching.isEmpty && !noRecipes;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 33,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .12),
              child: MenuIcon(
                noRecipes
                    ? Icons.menu_book_outlined
                    : noMatch
                    ? Icons.filter_alt_outlined
                    : Icons.check,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              noRecipes
                  ? '从一道拿手菜开始'
                  : noMatch
                  ? '换个口味，继续挑'
                  : hidden && available.isEmpty
                  ? '这些菜暂时休息一下'
                  : '这一轮挑完了',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              noRecipes
                  ? '记下喜欢的菜，下一餐就交给随机。'
                  : noMatch
                  ? '现有菜谱里没有符合这次筛选的菜，可以调整标签。'
                  : '已选的菜会保留，也可以直接添加这餐想吃的菜。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (noRecipes)
              FilledButton.icon(
                onPressed: () => editRecipe(context),
                icon: const MenuIcon(Icons.add, size: 19),
                label: const Text('添加我的菜谱'),
              ),
            if (noMatch) ...[
              FilledButton(onPressed: _filter, child: const Text('调整筛选')),
              TextButton(
                onPressed: () => setState(() {
                  _preferred.clear();
                  _excluded.clear();
                  _seen.clear();
                  _queue.clear();
                  _reconcile(data);
                }),
                child: const Text('清除筛选'),
              ),
            ],
            if (!noRecipes && !noMatch) ...[
              if (available.isNotEmpty)
                FilledButton(
                  onPressed: _busy ? null : () => _round(),
                  child: const Text('再抽一轮'),
                ),
              if (hidden)
                TextButton(
                  onPressed: _busy ? null : () => _round(restore: true),
                  child: const Text('恢复暂时隐藏的菜'),
                ),
              OutlinedButton(
                onPressed: _busy ? null : _openMenu,
                child: Text(data.selectedMenu.isEmpty ? '自己添加菜品' : '查看菜单'),
              ),
              TextButton(
                onPressed: _busy ? null : _filter,
                child: const Text('调整筛选'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
