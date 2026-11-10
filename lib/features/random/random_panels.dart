import '../../ui/menu_bottom_sheet.dart';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/glass_surface.dart';
import '../../ui/widgets.dart';
import '../../ui/rolling_count.dart';
import '../recipes/recipe_detail_page.dart';
import '../recipes/recipe_editor.dart';
import 'random_recipe_card.dart';
export 'random_filter_sheet.dart';

Future<T?> showHomeSheet<T>(
  BuildContext context, {
  required Widget child,
  bool fitContent = false,
}) => showMenuBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: !fitContent,
  useSafeArea: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  builder: (sheetContext) => LayoutBuilder(
    builder: (context, constraints) {
      final keyboard = MediaQuery.viewInsetsOf(sheetContext).bottom;
      final height = min(
        MediaQuery.sizeOf(sheetContext).height * .74,
        constraints.maxHeight - keyboard,
      );
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: fitContent ? 0 : height,
            maxHeight: height,
          ),
          child: SafeArea(top: false, child: child),
        ),
      );
    },
  ),
);

class HomeSheetHeader extends StatelessWidget {
  const HomeSheetHeader(this.title, {super.key, this.count});
  final String title;
  final int? count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            child: MenuTitleLine(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title),
                if (count != null) ...[
                  const Text(' · '),
                  RollingCount(value: count!),
                  const Text(' 道菜'),
                ],
              ],
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
  );
}

class RandomMenuSheet extends StatefulWidget {
  const RandomMenuSheet({super.key, required this.onRemoved});
  final ValueChanged<Iterable<String>> onRemoved;
  @override
  State<RandomMenuSheet> createState() => _RandomMenuSheetState();
}

class _RandomMenuSheetState extends State<RandomMenuSheet> {
  bool _busy = false;
  Future<void> _change(
    void Function(MenuData) edit, {
    Iterable<String> removed = const [],
  }) async {
    setState(() => _busy = true);
    final saved = await performAction(
      context,
      () => MenuScope.of(context).update(MenuWriteScope.settings, edit),
    );
    if (saved) widget.onRemoved(removed);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final recipes = {for (final r in store.data.recipes) r.id: r};
    final menu = store.data.selectedMenu.reversed
        .map((id) => recipes[id]!)
        .toList();
    return Column(
      children: [
        HomeSheetHeader('菜单', count: menu.length),
        Expanded(
          child: menu.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MenuIcon(Icons.restaurant_menu, size: 42),
                        SizedBox(height: 16),
                        Text('菜单里还没有菜', style: TextStyle(fontSize: 20)),
                        SizedBox(height: 8),
                        Text(
                          '随机挑一道，或者直接添加这餐想吃的菜。',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: menu.length,
                  itemBuilder: (context, index) {
                    final recipe = menu[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RecipeCover(recipe: recipe),
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _busy
                                    ? null
                                    : () =>
                                          showRecipeDetail(context, recipe.id),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  36,
                                  12,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      recipe.imagePaths.isEmpty
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.surface
                                          : const Color(0xa6000000),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  recipe.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: recipe.imagePaths.isEmpty
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurface
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              tooltip: '移除${recipe.name}',
                              onPressed: _busy
                                  ? null
                                  : () => _change(
                                      (d) => d.selectedMenu.remove(recipe.id),
                                      removed: [recipe.id],
                                    ),
                              icon: const GlassSurface(
                                radius: 16,
                                blurSigma: 24,
                                color: Color(0x18ffffff),
                                borderColor: Color(0x48ffffff),
                                child: SizedBox.square(
                                  dimension: 32,
                                  child: Center(
                                    child: MenuIcon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.white,
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            spacing: 10,
            children: [
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  tooltip: '清空菜单',
                  onPressed: _busy || menu.isEmpty
                      ? null
                      : () async {
                          if (!await confirmAction(
                            context,
                            title: '清空菜单？',
                            message: '菜单中的菜品将全部移出，菜谱和收藏会保留。',
                            confirmLabel: '确认清空',
                          )) {
                            return;
                          }
                          if (!mounted) return;
                          await _change(
                            (d) => d.selectedMenu.clear(),
                            removed: menu.map((r) => r.id).toList(),
                          );
                        },
                  icon: MenuIcon(
                    Icons.restart_alt,
                    size: 22,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _busy
                      ? null
                      : () => showHomeSheet<void>(
                          context,
                          child: const RandomPickerSheet(),
                        ),
                  child: const Text('添加菜品'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RandomPickerSheet extends StatefulWidget {
  const RandomPickerSheet({super.key});
  @override
  State<RandomPickerSheet> createState() => _RandomPickerSheetState();
}

class _RandomPickerSheetState extends State<RandomPickerSheet> {
  final _search = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final query = _search.text.trim().toLowerCase();
    final results = store.data.recipes
        .where(
          (r) => [
            r.name,
            ...r.tags,
          ].any((value) => value.toLowerCase().contains(query)),
        )
        .toList();
    return Column(
      children: [
        const HomeSheetHeader('添加菜品'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '搜索菜名、标签',
              prefixIcon: Padding(
                padding: EdgeInsets.all(14),
                child: MenuIcon(Icons.search),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(query.isEmpty ? '先记下一道喜欢的菜' : '没有找到相关菜谱'),
                      if (query.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _search.clear()),
                          child: const Text('清除搜索'),
                        ),
                    ],
                  ),
                ),
              for (final recipe in results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 60,
                    height: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: RecipeCover(recipe: recipe),
                    ),
                  ),
                  title: Text(recipe.name),
                  subtitle: recipe.tags.isEmpty
                      ? null
                      : Text(recipe.tags.join(' · ')),
                  onTap: _busy
                      ? null
                      : () => showRecipeDetail(context, recipe.id),
                  trailing: IconButton(
                    tooltip: store.data.selectedMenu.contains(recipe.id)
                        ? '已在菜单'
                        : '添加${recipe.name}',
                    icon: MenuIcon(
                      store.data.selectedMenu.contains(recipe.id)
                          ? Icons.check
                          : Icons.add,
                    ),
                    onPressed:
                        _busy || store.data.selectedMenu.contains(recipe.id)
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await performAction(
                              context,
                              () => store.update(
                                MenuWriteScope.settings,
                                (d) => d.selectedMenu.add(recipe.id),
                              ),
                            );
                            if (mounted) setState(() => _busy = false);
                          },
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const MenuIcon(Icons.add),
                title: const Text('新建菜谱'),
                trailing: const MenuIcon(Icons.chevron_right),
                onTap: _busy
                    ? null
                    : () async {
                        await editRecipe(context);
                        if (mounted) setState(() => _search.clear());
                      },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('选好了 · '),
                  RollingCount(value: store.data.selectedMenu.length),
                  const Text(' 道菜'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
