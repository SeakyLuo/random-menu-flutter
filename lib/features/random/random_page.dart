import '../../ui/menu_icon.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../recipes/recipe_detail_page.dart';
import 'random_recipe_card.dart';

class RandomPage extends StatefulWidget {
  const RandomPage({super.key, required this.onOpenRecipes});
  final VoidCallback onOpenRecipes;
  @override
  State<RandomPage> createState() => _RandomPageState();
}

class _RandomPageState extends State<RandomPage> {
  final _seen = <String>{};
  final _preferred = <String>{};
  final _excluded = <String>{};
  final _random = Random();
  String? _current;
  bool _saving = false;

  List<Recipe> _matching(MenuData data, {bool includeHidden = false}) => data
      .recipes
      .where(
        (r) =>
            (includeHidden || r.hiddenRounds == 0) &&
            (_preferred.isEmpty || r.tags.any(_preferred.contains)) &&
            !r.tags.any(_excluded.contains),
      )
      .toList();
  List<Recipe> _available(MenuData data) => _matching(data)
      .where((r) => !_seen.contains(r.id) && !data.selectedMenu.contains(r.id))
      .toList();
  void _choose(MenuData data) {
    final available = _available(data);
    if (!available.any((r) => r.id == _current)) {
      _current = available.isEmpty
          ? null
          : available[_random.nextInt(available.length)].id;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = MenuScope.of(context).data;
    final tags = data.recipes.expand((r) => r.tags).toSet();
    _preferred.retainAll(tags);
    _excluded.retainAll(tags);
    _choose(data);
  }

  void _skip(MenuData data) => setState(() {
    _seen.add(_current!);
    _current = null;
    _choose(data);
  });

  Future<void> _select(MenuStore store) async {
    final id = _current!;
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => store.update((d) {
        d.selectedMenu.add(id);
      }),
      success: '已加入本次菜单',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) {
        _seen.add(id);
        _current = null;
        _choose(store.data);
      }
    });
  }

  Future<void> _filters(MenuStore store) async {
    final preferred = {..._preferred};
    final excluded = {..._excluded};
    final tags = store.data.recipes.expand((r) => r.tags).toSet().toList()
      ..sort();
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('今天想吃什么', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('优先标签匹配其中一个即可，排除标签不会参与抽取。'),
                  if (tags.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('还没有标签，可以先到菜谱里添加。'),
                    ),
                  if (tags.isNotEmpty) ...[
                    const SectionTitle('想吃的'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final tag in tags)
                          FilterChip(
                            label: Text(tag),
                            selected: preferred.contains(tag),
                            onSelected: (on) => setSheetState(() {
                              if (on) {
                                preferred.add(tag);
                                excluded.remove(tag);
                              } else {
                                preferred.remove(tag);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SectionTitle('这次不吃'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final tag in tags)
                          FilterChip(
                            label: Text(tag),
                            selected: excluded.contains(tag),
                            onSelected: (on) => setSheetState(() {
                              if (on) {
                                excluded.add(tag);
                                preferred.remove(tag);
                              } else {
                                excluded.remove(tag);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('开始挑选'),
                  ),
                  TextButton(
                    onPressed: () => setSheetState(() {
                      preferred.clear();
                      excluded.clear();
                    }),
                    child: const Text('清除筛选'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    setState(() {
      _preferred
        ..clear()
        ..addAll(preferred);
      _excluded
        ..clear()
        ..addAll(excluded);
    });
    await _reshuffle(store);
  }

  Future<void> _reshuffle(MenuStore store) async {
    if (_saving) return;
    final previous = _current;
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => store.update((data) {
        for (final recipe in data.recipes) {
          if (recipe.hiddenRounds > 0) recipe.hiddenRounds--;
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) {
        _seen.clear();
        final choices = _available(store.data);
        if (choices.length > 1) choices.removeWhere((r) => r.id == previous);
        _current = choices.isEmpty
            ? null
            : choices[_random.nextInt(choices.length)].id;
      }
    });
  }

  void _hidden(MenuStore store) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final hidden = _matching(
            store.data,
            includeHidden: true,
          ).where((r) => r.hiddenRounds > 0).toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Text(
                      '暂时不推荐的菜谱',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: hidden.isEmpty
                        ? const Center(child: Text('匹配的菜谱都已恢复推荐'))
                        : ListView.builder(
                            itemCount: hidden.length,
                            itemBuilder: (context, index) {
                              final recipe = hidden[index];
                              return ListTile(
                                title: Text(recipe.name),
                                subtitle: Text(
                                  '再抽 ${recipe.hiddenRounds} 轮后恢复',
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        RecipeDetailPage(recipeId: recipe.id),
                                  ),
                                ),
                                trailing: TextButton(
                                  onPressed: () async {
                                    final success = await performAction(
                                      context,
                                      () => store.update(
                                        (data) =>
                                            data.recipes
                                                    .firstWhere(
                                                      (r) => r.id == recipe.id,
                                                    )
                                                    .hiddenRounds =
                                                0,
                                      ),
                                      success: '已恢复推荐',
                                    );
                                    if (success && mounted) {
                                      setState(() {
                                        _seen.remove(recipe.id);
                                        _choose(store.data);
                                      });
                                    }
                                  },
                                  child: const Text('恢复推荐'),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _reshuffle(store),
                      child: const Text('再抽一轮'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _menu(MenuStore store) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final recipes = {
            for (final recipe in store.data.recipes) recipe.id: recipe,
          };
          final chosen = store.data.selectedMenu
              .map((id) => recipes[id]!)
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Text(
                      '本次菜单 · ${chosen.length} 道菜',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Expanded(
                    child: chosen.isEmpty
                        ? const SingleChildScrollView(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                MenuIcon(Icons.restaurant_menu, size: 40),
                                SizedBox(height: 16),
                                Text('菜单还是空的', style: TextStyle(fontSize: 20)),
                                SizedBox(height: 12),
                                Text(
                                  '抽到喜欢的菜，点“加入菜单”就能留在这里。',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: chosen.length,
                            itemBuilder: (context, index) {
                              final recipe = chosen[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                leading: const MenuIcon(
                                  Icons.check_circle_outline_rounded,
                                ),
                                title: Text(recipe.name),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        RecipeDetailPage(recipeId: recipe.id),
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: '移出菜单',
                                  icon: const MenuIcon(Icons.close_rounded),
                                  onPressed: () async {
                                    final removed = await performAction(
                                      context,
                                      () => store.update(
                                        (d) => d.selectedMenu.remove(recipe.id),
                                      ),
                                      success: '已移出菜单',
                                    );
                                    if (removed && mounted) {
                                      setState(() {
                                        _seen.remove(recipe.id);
                                        _choose(store.data);
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  if (chosen.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: OutlinedButton(
                        onPressed: () async {
                          if (!await confirmAction(
                            context,
                            title: '清空本次菜单？',
                            message: '菜谱仍会保留，可以重新挑选。',
                            confirmLabel: '清空',
                          )) {
                            return;
                          }
                          if (!context.mounted) return;
                          final cleared = await performAction(
                            context,
                            () => store.update((d) => d.selectedMenu.clear()),
                            success: '已清空菜单',
                          );
                          if (cleared && mounted) {
                            setState(() {
                              _seen.clear();
                              _choose(store.data);
                            });
                          }
                        },
                        child: const Text('清空菜单'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final data = store.data;
    final matching = _matching(data);
    final tagged = _matching(data, includeHidden: true);
    final recipe = _current == null
        ? null
        : data.recipes.firstWhere((r) => r.id == _current);
    return MenuPage(
      title: '今天吃什么',
      subtitle: '把纠结交给随机，把喜欢留在菜单',
      actions: [
        IconButton(
          tooltip: '再抽一轮',
          onPressed: _saving ? null : () => _reshuffle(store),
          icon: const MenuIcon(Icons.shuffle_rounded),
        ),
        IconButton(
          tooltip: '筛选菜谱',
          onPressed: () => _filters(store),
          icon: Badge(
            isLabelVisible: _preferred.isNotEmpty || _excluded.isNotEmpty,
            child: const MenuIcon(Icons.tune_rounded),
          ),
        ),
        IconButton(
          tooltip: '本次菜单',
          onPressed: () => _menu(store),
          icon: Badge(
            isLabelVisible: data.selectedMenu.isNotEmpty,
            label: Text('${data.selectedMenu.length}'),
            child: const MenuIcon(Icons.receipt_long_outlined),
          ),
        ),
      ],
      child: data.recipes.isEmpty
          ? EmptyState(
              icon: Icons.restaurant_rounded,
              title: '从一道拿手菜开始',
              message: '记下做过的菜，下次不知道吃什么时，\n就来这里抽一道。',
              actionLabel: '添加我的菜谱',
              onAction: widget.onOpenRecipes,
            )
          : tagged.isEmpty
          ? EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: '没有符合条件的菜',
              message: '换一组标签，给今天多一点选择。',
              actionLabel: '调整筛选',
              onAction: () => _filters(store),
            )
          : matching.isEmpty
          ? EmptyState(
              icon: Icons.visibility_off_outlined,
              title: '这些菜谱正在暂时休息',
              message: '匹配的菜谱都设置了暂不推荐。\n可以恢复推荐，或再抽一轮减少隐藏轮次。',
              actionLabel: '查看隐藏菜谱',
              onAction: () => _hidden(store),
            )
          : recipe == null
          ? EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: '这一轮已经挑完了',
              message: data.selectedMenu.isEmpty
                  ? '再抽一轮，说不定会有新的灵感。'
                  : '喜欢的菜已留在本次菜单里。\n重新抽取时会保留已选菜品。',
              actionLabel: _availableAfterRestart(data) ? '再抽一轮' : '查看本次菜单',
              onAction: () {
                if (_availableAfterRestart(data)) {
                  _reshuffle(store);
                } else {
                  _menu(store);
                }
              },
            )
          : _card(context, store, recipe),
    );
  }

  bool _availableAfterRestart(MenuData data) =>
      _matching(data).any((r) => !data.selectedMenu.contains(r.id));

  Widget _card(BuildContext context, MenuStore store, Recipe recipe) =>
      RandomRecipeCard(
        recipe: recipe,
        busy: _saving,
        menuCount: store.data.selectedMenu.length,
        onOpen: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => RecipeDetailPage(recipeId: recipe.id),
          ),
        ),
        onSelect: () => _select(store),
        onSkip: () => _skip(store.data),
        onReshuffle: () => _reshuffle(store),
      );
}
