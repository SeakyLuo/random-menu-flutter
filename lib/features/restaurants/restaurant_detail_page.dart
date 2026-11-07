import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/theme.dart';
import '../../ui/menu_popup.dart';
import '../../ui/widgets.dart';
import 'restaurant_detail_gallery.dart';
import 'restaurant_detail_header.dart';
import 'restaurant_gallery_data.dart';
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
  int _tab = 0;
  final _scroll = ScrollController();
  final _headerKey = GlobalKey();
  final _tabOffsets = [0.0, 0.0];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index == _tab) return;
    final header = _headerKey.currentContext!.findRenderObject()! as RenderBox;
    final start = header.size.height;
    final inContent = _scroll.offset >= start;
    _tabOffsets[_tab] = math.max(0, _scroll.offset - start);
    setState(() => _tab = index);
    if (inContent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scroll.jumpTo(
            math.min(
              start + _tabOffsets[index],
              _scroll.position.maxScrollExtent,
            ),
          );
        }
      });
    }
  }

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

  void _more(String action, Restaurant restaurant) {
    switch (action) {
      case 'edit':
        editRestaurant(context, restaurant: restaurant);
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
    final gallery = restaurantGallery(restaurant);
    final dishPaths = gallery
        .where((photo) => !photo.isEnvironment)
        .map((photo) => photo.path)
        .toSet()
        .toList();
    final environmentPaths = gallery
        .where((photo) => photo.isEnvironment)
        .map((photo) => photo.path)
        .toSet()
        .toList();
    final scheme = Theme.of(context).colorScheme;
    final background = Theme.of(context).scaffoldBackgroundColor;
    Widget control(Widget child) => Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox.square(dimension: 40, child: child),
    );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 48,
                  backgroundColor: background,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  systemOverlayStyle: menuSystemUiStyle(scheme.brightness),
                  leadingWidth: 60,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    child: control(
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.pop(context),
                        icon: MenuIcon(
                          Icons.arrow_back,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    control(
                      IconButton(
                        tooltip: restaurant.favorite ? '取消收藏' : '收藏餐厅',
                        onPressed: _savingFavorite
                            ? null
                            : () => _favorite(restaurant),
                        icon: MenuIcon(
                          restaurant.favorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: restaurant.favorite
                              ? const Color(0xffef4762)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final menu = MenuPopupButton<String>(
                          tooltip: '更多',
                          icon: MenuIcon(
                            Icons.more_horiz,
                            color: scheme.onSurfaceVariant,
                          ),
                          onSelected: (action) => _more(action, restaurant),
                          itemBuilder: (_) => [
                            const MenuPopupItem(
                              value: 'edit',
                              icon: Icons.edit_outlined,
                              child: Text('编辑餐厅'),
                            ),
                            const MenuPopupItem(
                              value: 'visit',
                              icon: Icons.add,
                              child: Text('新增用餐记录'),
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
                        );
                        return control(menu);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    key: _headerKey,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RestaurantDetailGallery(
                        name: restaurant.name,
                        dishPaths: dishPaths,
                        environmentPaths: environmentPaths,
                      ),
                      RestaurantDetailInfo(restaurant: restaurant),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _RestaurantTabs(
                    height: math.max(
                      48,
                      MediaQuery.textScalerOf(context).scale(14) * 1.4 + 20,
                    ),
                    color: background,
                    child: TabBar(
                      onTap: (index) => _switchTab(index),
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                      labelColor: scheme.primary,
                      unselectedLabelColor: scheme.onSurfaceVariant,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerHeight: 0,
                      indicator: UnderlineTabIndicator(
                        borderSide: BorderSide(width: 2, color: scheme.primary),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      tabs: [
                        Tab(text: '用餐记录 ${records.length}'),
                        Tab(text: '吃过的菜 ${dishes.length}'),
                      ],
                    ),
                  ),
                ),
                if (_tab == 0)
                  if (records.isEmpty)
                    const SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.edit_note,
                        title: '还没有用餐记录',
                        message: '可从右上角更多添加用餐记录。',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => RestaurantVisitCard(
                          restaurant: restaurant,
                          visit: records[index],
                        ),
                      ),
                    )
                else
                  RestaurantDishSliver(restaurant: restaurant, dishes: dishes),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.viewPaddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantTabs extends SliverPersistentHeaderDelegate {
  _RestaurantTabs({
    required this.height,
    required this.color,
    required this.child,
  });
  final double height;
  final Color color;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: color, child: child);
  @override
  bool shouldRebuild(covariant _RestaurantTabs oldDelegate) =>
      oldDelegate.height != height ||
      oldDelegate.color != color ||
      oldDelegate.child != child;
}
