import '../../ui/menu_icon.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../photo_import/photo_import_page.dart';
import 'restaurant_editor.dart';
import 'restaurant_entries.dart';
import 'restaurant_filter.dart';
import 'restaurant_images.dart';
import 'visit_detail_page.dart';

class RestaurantDetailPage extends StatefulWidget {
  const RestaurantDetailPage({
    super.key,
    required this.restaurantId,
    this.query,
  });
  final String restaurantId;
  final RestaurantQuery? query;
  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  late RestaurantQuery? query = widget.query?.copy();
  String get restaurantId => widget.restaurantId;
  Future<void> delete(Restaurant r) async {
    final store = MenuScope.of(context);
    if (!await confirmAction(
      context,
      title: '删除餐厅？',
      message:
          '“${r.name}”以及它的 ${r.foods.length} 道菜品和 ${r.records.length} 条用餐记录都会被删除，无法恢复。',
    )) {
      return;
    }
    if (!mounted) return;
    final success = await performAction(
      context,
      () => store.update(
        (draft) => draft.restaurants.removeWhere((r) => r.id == restaurantId),
      ),
      success: '餐厅已删除',
    );
    if (success && mounted) Navigator.pop(context);
  }

  Future<void> deleteDish(RestaurantDish dish) async {
    final store = MenuScope.of(context);
    if (!await confirmAction(
      context,
      title: '删除菜品？',
      message: '删除“${dish.name}”。已有用餐记录中的菜品快照会保留。',
    )) {
      return;
    }
    if (!mounted) return;
    await performAction(
      context,
      () => store.update(
        (draft) => draft.restaurants
            .firstWhere((r) => r.id == restaurantId)
            .foods
            .removeWhere((d) => d.id == dish.id),
      ),
      success: '菜品已删除',
    );
  }

  Future<void> moveDish(int from, int to) async {
    final store = MenuScope.of(context);
    await performAction(
      context,
      () => store.update((draft) {
        final foods = draft.restaurants
            .firstWhere((r) => r.id == restaurantId)
            .foods;
        final dish = foods.removeAt(from);
        foods.insert(to, dish);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final r = store.data.restaurants
        .where((r) => r.id == restaurantId)
        .firstOrNull;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('餐厅')),
        body: const SizedBox.shrink(),
      );
    }
    final filterRecords =
        query != null && (query!.hasRecords || query!.hasRegion);
    final records =
        r.records
            .where((v) => !filterRecords || query!.matchesVisit(r, v))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final environments = r.records.expand((v) => v.imagePaths).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          IconButton(
            tooltip: r.favorite ? '取消收藏' : '收藏餐厅',
            icon: MenuIcon(
              r.favorite ? Icons.favorite : Icons.favorite_border,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () => performAction(
              context,
              () => store.update((draft) {
                final r = draft.restaurants.firstWhere(
                  (r) => r.id == restaurantId,
                );
                r.favorite = !r.favorite;
              }),
              success: r.favorite ? '已取消收藏' : '已收藏餐厅',
            ),
          ),
          IconButton(
            tooltip: '编辑餐厅',
            onPressed: () => editRestaurant(context, restaurant: r),
            icon: const MenuIcon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            icon: const MenuIcon(Icons.more_horiz),
            tooltip: '更多操作',
            onSelected: (value) {
              if (value == 'photos') {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PhotoImportPage(restaurantId: restaurantId),
                  ),
                );
              } else {
                delete(r);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'photos', child: Text('从照片新增用餐记录')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('删除餐厅')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              112 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (r.category.isNotEmpty) Chip(label: Text(r.category)),
                  Chip(
                    avatar: const MenuIcon(Icons.restaurant_outlined, size: 18),
                    label: Text('${r.records.length} 次用餐'),
                  ),
                  if (r.averageCost > 0)
                    Chip(label: Text('人均 ¥${money(r.averageCost)}')),
                ],
              ),
              if (r.addresses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final address in r.addresses)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MenuIcon(
                                Icons.place_outlined,
                                size: 19,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: SelectableText(address)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (r.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(r.note, style: const TextStyle(height: 1.6)),
                ),
              if (r.link.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => performAction(
                      context,
                      () => Clipboard.setData(ClipboardData(text: r.link)),
                      success: '链接已复制',
                    ),
                    icon: const MenuIcon(Icons.link),
                    label: const Text('复制店铺链接'),
                  ),
                ),
              SectionTitle(
                '菜品 · ${r.foods.length}',
                trailing: TextButton.icon(
                  onPressed: () => editRestaurantDish(context, r),
                  icon: const MenuIcon(Icons.add, size: 18),
                  label: const Text('添加菜品'),
                ),
              ),
              if (r.foods.isEmpty)
                _InlineEmpty(
                  message: '记下招牌菜，下次点单更轻松。',
                  label: '添加第一道菜',
                  onPressed: () => editRestaurantDish(context, r),
                ),
              for (var i = 0; i < r.foods.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                      leading: r.foods[i].imagePaths.isEmpty
                          ? const MenuIcon(Icons.ramen_dining_outlined)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(r.foods[i].imagePaths.first),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stack) =>
                                    const SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: MenuIcon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                              ),
                            ),
                      title: Text(
                        r.foods[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          if (r.foods[i].price > 0)
                            '¥${money(r.foods[i].price)}',
                          if (r.foods[i].note.isNotEmpty) r.foods[i].note,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RestaurantDishDetailPage(
                            restaurantId: restaurantId,
                            dishId: r.foods[i].id,
                          ),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const MenuIcon(Icons.more_horiz),
                        tooltip: '菜品操作',
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              editRestaurantDish(context, r, dish: r.foods[i]);
                            case 'up':
                              moveDish(i, i - 1);
                            case 'down':
                              moveDish(i, i + 1);
                            case 'delete':
                              deleteDish(r.foods[i]);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('编辑菜品'),
                          ),
                          if (i > 0)
                            const PopupMenuItem(value: 'up', child: Text('上移')),
                          if (i < r.foods.length - 1)
                            const PopupMenuItem(
                              value: 'down',
                              child: Text('下移'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除菜品'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SectionTitle(
                '用餐记录 · ${records.length}',
                trailing: TextButton.icon(
                  onPressed: () => editRestaurantVisit(context, r),
                  icon: const MenuIcon(Icons.add, size: 18),
                  label: const Text('记录用餐'),
                ),
              ),
              if (filterRecords)
                Row(
                  children: [
                    const Expanded(child: Text('当前按筛选条件显示相关记录')),
                    TextButton(
                      onPressed: () => setState(() => query = null),
                      child: const Text('显示全部'),
                    ),
                  ],
                ),
              if (records.isEmpty)
                _InlineEmpty(
                  message: filterRecords
                      ? '没有符合条件的用餐记录。'
                      : '还没有用餐记录，记下今天吃得怎么样。',
                  label: filterRecords ? '显示全部记录' : '记录第一次用餐',
                  onPressed: filterRecords
                      ? () => setState(() => query = null)
                      : () => editRestaurantVisit(context, r),
                ),
              for (final visit in records)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
                      title: Text(
                        '${dayLabel(visit.date)} ${TimeOfDay.fromDateTime(visit.date).format(context)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '共 ¥${money(visit.totalCost)} · ${visit.companions.length + 1} 人 · 人均 ¥${money(visit.totalCost / (visit.companions.length + 1))}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              visit.companions.isEmpty
                                  ? '独自用餐'
                                  : '同行：${visit.companions.join('、')}',
                            ),
                            if (visit.address.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  visit.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (visit.items.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  visit.items
                                      .map((i) => '${i.name} ×${i.quantity}')
                                      .join('、'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => VisitDetailPage(
                            restaurantId: restaurantId,
                            visitId: visit.id,
                          ),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const MenuIcon(Icons.more_horiz),
                        tooltip: '用餐记录操作',
                        onSelected: (value) {
                          if (value == 'edit') {
                            editRestaurantVisit(context, r, visit: visit);
                          } else {
                            removeRestaurantVisit(context, restaurantId, visit);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('编辑记录')),
                          PopupMenuItem(value: 'delete', child: Text('删除记录')),
                        ],
                      ),
                    ),
                  ),
                ),
              if (environments.isNotEmpty) ...[
                SectionTitle('环境相册 · ${environments.length}'),
                RestaurantImages(paths: environments),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.message,
    required this.label,
    required this.onPressed,
  });
  final String message;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const MenuIcon(Icons.add),
          label: Text(label),
        ),
      ],
    ),
  );
}

class RestaurantDishDetailPage extends StatelessWidget {
  const RestaurantDishDetailPage({
    super.key,
    required this.restaurantId,
    required this.dishId,
  });
  final String restaurantId;
  final String dishId;
  @override
  Widget build(BuildContext context) {
    final restaurant = MenuScope.of(
      context,
    ).data.restaurants.firstWhere((r) => r.id == restaurantId);
    final dish = restaurant.foods.firstWhere((d) => d.id == dishId);
    return Scaffold(
      appBar: AppBar(
        title: Text(dish.name),
        actions: [
          IconButton(
            tooltip: '编辑菜品',
            onPressed: () =>
                editRestaurantDish(context, restaurant, dish: dish),
            icon: const MenuIcon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '¥${money(dish.price)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (dish.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(dish.note, style: const TextStyle(height: 1.6)),
            ),
          if (dish.imagePaths.isNotEmpty)
            RestaurantImages(paths: dish.imagePaths),
        ],
      ),
    );
  }
}
