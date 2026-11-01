import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';

import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../recipes/recipe_detail_page.dart';
import '../recipes/recipe_editor.dart';
import '../restaurants/restaurant_detail_page.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final recipes = data.recipes.where((r) => r.favorite).toList();
    final restaurants = data.restaurants.where((r) => r.favorite).toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的收藏'),
          bottom: TabBar(
            tabs: [
              Tab(text: '菜谱 ${recipes.length}'),
              Tab(text: '餐厅 ${restaurants.length}'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            recipes.isEmpty
                ? const EmptyState(
                    icon: Icons.favorite_border,
                    title: '还没有收藏菜谱',
                    message: '在菜谱详情点亮爱心，喜欢的菜就会收在这里。',
                  )
                : ListView.builder(
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      return ListTile(
                        leading: const MenuIcon(Icons.soup_kitchen_outlined),
                        title: Text(recipe.name),
                        subtitle: recipe.tags.isEmpty
                            ? null
                            : Text(recipe.tags.join(' · ')),
                        trailing: const MenuIcon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RecipeDetailPage(recipeId: recipe.id),
                          ),
                        ),
                      );
                    },
                  ),
            restaurants.isEmpty
                ? const EmptyState(
                    icon: Icons.favorite_border,
                    title: '还没有收藏餐厅',
                    message: '在餐厅详情点亮爱心，下次探店更容易找到。',
                  )
                : ListView.builder(
                    itemCount: restaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = restaurants[index];
                      return ListTile(
                        leading: const MenuIcon(Icons.storefront_outlined),
                        title: Text(restaurant.name),
                        subtitle: restaurant.category.isEmpty
                            ? null
                            : Text(restaurant.category),
                        trailing: const MenuIcon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => RestaurantDetailPage(
                              restaurantId: restaurant.id,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

enum PersonalListKind { toCook, toEat, dislikes }

class PersonalListPage extends StatelessWidget {
  const PersonalListPage({super.key, required this.kind});
  final PersonalListKind kind;
  String get title => switch (kind) {
    PersonalListKind.toCook => '想做',
    PersonalListKind.toEat => '想吃',
    PersonalListKind.dislikes => '不喜欢',
  };
  List<String> _items(MenuData data) => switch (kind) {
    PersonalListKind.toCook => data.toCook,
    PersonalListKind.toEat => data.toEat,
    PersonalListKind.dislikes => data.dislikes,
  };
  @override
  Widget build(BuildContext context) {
    final items = _items(MenuScope.of(context).data);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '添加$title',
            onPressed: () => _add(context),
            icon: const MenuIcon(Icons.add),
          ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.edit_note,
              title: '还没有$title的记录',
              message: switch (kind) {
                PersonalListKind.toCook => '先记下菜名，有空时再整理成自己的菜谱。',
                PersonalListKind.toEat => '把惦记的食物或餐厅记下来。',
                PersonalListKind.dislikes => '记录你的口味偏好，方便自己查看。此清单不会自动排除随机菜谱。',
              },
              actionLabel: '添加记录',
              onAction: () => _add(context),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (kind == PersonalListKind.dislikes)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Text('此处用于记录口味偏好，不会自动排除随机菜谱。'),
                  ),
                for (final item in items)
                  Card(
                    child: ListTile(
                      title: Text(item),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (kind == PersonalListKind.toCook)
                            TextButton(
                              onPressed: () => _makeRecipe(context, item),
                              child: const Text('做成菜谱'),
                            ),
                          IconButton(
                            tooltip: '移除',
                            onPressed: () => _remove(context, item),
                            icon: const MenuIcon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _makeRecipe(BuildContext context, String name) async {
    final store = MenuScope.of(context);
    final saved = await editRecipe(context, initialName: name);
    if (saved && context.mounted) {
      await performAction(
        context,
        () => store.update((draft) => draft.toCook.remove(name)),
      );
    }
  }

  Future<void> _remove(BuildContext context, String item) async {
    final store = MenuScope.of(context);
    if (!await confirmAction(
          context,
          title: '移除记录',
          message: '从$title清单移除“$item”？',
          confirmLabel: '移除',
        ) ||
        !context.mounted) {
      return;
    }
    await performAction(
      context,
      () => store.update((draft) => _items(draft).remove(item)),
      success: '已移除',
    );
  }

  Future<void> _add(BuildContext context) async {
    final store = MenuScope.of(context);
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('添加$title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: '名称'),
          onSubmitted: (_) => _submit(dialogContext, controller, store),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _submit(dialogContext, controller, store),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    await performAction(
      context,
      () => store.update((draft) => _items(draft).insert(0, value)),
      success: '已添加',
    );
  }

  void _submit(
    BuildContext context,
    TextEditingController controller,
    MenuStore store,
  ) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      showToast(context, '请输入名称');
      return;
    }
    if (_items(store.data).contains(value)) {
      showToast(context, '清单中已有这条记录');
      return;
    }
    Navigator.pop(context, value);
  }
}
