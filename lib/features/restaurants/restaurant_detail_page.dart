import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_popup.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import '../photo_import/photo_import_page.dart';
import 'restaurant_dish_browser.dart';
import 'restaurant_dish_summary.dart';
import 'restaurant_dishes_page.dart';
import 'restaurant_editor.dart';
import 'restaurant_entries.dart';
import 'restaurant_visit_card.dart';

class RestaurantDetailPage extends StatefulWidget {
  const RestaurantDetailPage({super.key, required this.restaurantId});
  final String restaurantId;
  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  bool _savingFavorite = false;
  bool _deleting = false;

  Future<void> _favorite(Restaurant restaurant) async {
    setState(() => _savingFavorite = true);
    await performAction(
      context,
      () => MenuScope.of(context).update(
        MenuWriteScope.restaurant(restaurant.id),
        (data) {
          final item = data.restaurants.firstWhere(
            (r) => r.id == restaurant.id,
          );
          item.favorite = !item.favorite;
        },
      ),
    );
    if (mounted) setState(() => _savingFavorite = false);
  }

  Future<void> _delete(Restaurant restaurant) async {
    if (!await confirmAction(
      context,
      title: '删除餐厅？',
      message:
          '删除“${restaurant.name}”及其 ${restaurant.records.length} 条消费记录和照片。此操作无法撤销。',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _deleting = true);
    final saved = await performAction(
      context,
      () => MenuScope.of(context).update(
        MenuWriteScope.restaurant(restaurant.id),
        (data) => data.restaurants.removeWhere((r) => r.id == restaurant.id),
      ),
      success: '餐厅已删除',
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _deleting = false);
    }
  }

  void _more(String action, Restaurant restaurant, List<String> environments) {
    switch (action) {
      case 'visit':
        editRestaurantVisit(context, restaurant);
      case 'import':
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PhotoImportPage(restaurantId: restaurant.id),
          ),
        );
      case 'dishes':
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => RestaurantDishesPage(restaurantId: restaurant.id),
          ),
        );
      case 'environment':
        showPhotoViewer(context, environments, 0, title: '用餐环境');
      case 'link':
        performAction(
          context,
          () => Clipboard.setData(ClipboardData(text: restaurant.link)),
          success: '链接已复制',
        );
      case 'delete':
        _delete(restaurant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = MenuScope.of(
      context,
    ).data.restaurants.where((r) => r.id == widget.restaurantId).firstOrNull;
    if (restaurant == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(title: const Text('餐厅')),
        body: EmptyState(
          icon: Icons.storefront_outlined,
          title: '餐厅已被移除',
          message: '回到列表，继续收集喜欢的地方。',
          actionLabel: '返回列表',
          onAction: () => Navigator.pop(context),
        ),
      );
    }
    final dishes = restaurantDishSummaries(restaurant);
    final records = [...restaurant.records]
      ..sort((a, b) => b.date.compareTo(a.date));
    final addresses = {
      ...restaurant.addressEntries.map((address) => address.fullAddress),
      ...restaurant.addresses,
    };
    final environments = {
      for (final visit in records) ...visit.imagePaths,
    }.toList();
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          titleSpacing: 0,
          title: const Text('餐厅', style: TextStyle(fontSize: 18)),
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
            icon: const MenuIcon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: '编辑餐厅',
              onPressed: () => editRestaurant(context, restaurant: restaurant),
              icon: const MenuIcon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: restaurant.favorite ? '取消收藏' : '收藏餐厅',
              onPressed: _savingFavorite ? null : () => _favorite(restaurant),
              icon: MenuIcon(
                restaurant.favorite ? Icons.favorite : Icons.favorite_border,
                color: restaurant.favorite
                    ? const Color(0xffef4762)
                    : scheme.onSurfaceVariant,
              ),
            ),
            MenuPopupButton<String>(
              tooltip: '更多',
              onSelected: (action) => _more(action, restaurant, environments),
              itemBuilder: (_) => [
                const MenuPopupItem(
                  value: 'visit',
                  icon: Icons.add,
                  child: Text('记一笔'),
                ),
                const MenuPopupItem(
                  value: 'import',
                  icon: Icons.add_photo_alternate_outlined,
                  child: Text('从照片新增用餐记录'),
                ),
                const MenuPopupItem(
                  value: 'dishes',
                  icon: Icons.edit_note,
                  child: Text('管理菜品资料'),
                ),
                if (environments.isNotEmpty)
                  const MenuPopupItem(
                    value: 'environment',
                    icon: Icons.photo_outlined,
                    child: Text('用餐环境'),
                  ),
                if (restaurant.link.isNotEmpty)
                  const MenuPopupItem(
                    value: 'link',
                    icon: Icons.link,
                    child: Text('复制餐厅链接'),
                  ),
                MenuPopupItem(
                  value: 'delete',
                  icon: Icons.delete_outline,
                  enabled: !_deleting,
                  destructive: true,
                  child: const Text('删除餐厅'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name,
                            style: const TextStyle(
                              fontSize: 22,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (restaurant.category.isNotEmpty ||
                              restaurant.averageCost > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                [
                                  if (restaurant.category.isNotEmpty)
                                    restaurant.category,
                                  if (restaurant.averageCost > 0)
                                    '人均 ¥${money(restaurant.averageCost)}',
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          for (final address in addresses)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onLongPress: () => performAction(
                                  context,
                                  () => Clipboard.setData(
                                    ClipboardData(text: address),
                                  ),
                                  success: '地址已复制',
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: MenuIcon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (restaurant.note.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: SelectableText(
                                restaurant.note,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        labelColor: scheme.primary,
                        unselectedLabelColor: scheme.onSurfaceVariant,
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        indicatorSize: TabBarIndicatorSize.label,
                        dividerHeight: 0,
                        indicator: UnderlineTabIndicator(
                          borderSide: BorderSide(
                            width: 2,
                            color: scheme.primary,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        tabs: [
                          Tab(text: '用餐记录 ${records.length}'),
                          Tab(text: '吃过的菜 ${dishes.length}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: TextButton.icon(
                                    onPressed: () => editRestaurantVisit(
                                      context,
                                      restaurant,
                                    ),
                                    icon: const MenuIcon(Icons.add, size: 17),
                                    label: const Text(
                                      '记一笔',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: records.isEmpty
                                    ? const EmptyState(
                                        icon: Icons.edit_note,
                                        title: '还没有用餐记录',
                                        message: '记下吃过的菜和感受，下次再来更好选。',
                                      )
                                    : ListView.builder(
                                        key: PageStorageKey(
                                          'restaurant-visits:${restaurant.id}',
                                        ),
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          24,
                                        ),
                                        itemCount: records.length,
                                        itemBuilder: (_, index) =>
                                            RestaurantVisitCard(
                                              restaurant: restaurant,
                                              visit: records[index],
                                            ),
                                      ),
                              ),
                            ],
                          ),
                          RestaurantDishBrowser(
                            restaurant: restaurant,
                            dishes: dishes,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
