import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/library_widgets.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../photo_import/photo_import_page.dart';
import 'restaurant_dishes_page.dart';
import 'restaurant_editor.dart';
import 'restaurant_entries.dart';
import 'restaurant_filter.dart';
import 'restaurant_visit_card.dart';

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
  bool _saving = false;
  Future<void> _delete(Restaurant r) async {
    if (!await confirmAction(
      context,
      title: '删除餐厅？',
      message: '删除“${r.name}”及其 ${r.records.length} 条消费记录和照片。此操作无法撤销。',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => MenuScope.of(
        context,
      ).update((d) => d.restaurants.removeWhere((item) => item.id == r.id)),
      success: '餐厅已删除',
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final r = store.data.restaurants
        .where((r) => r.id == widget.restaurantId)
        .firstOrNull;
    if (r == null) {
      return Scaffold(
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
    final records = [...r.records]..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: 48,
        title: const Text('餐厅详情', style: TextStyle(fontSize: 20)),
        leading: IconButton(
          tooltip: '关闭',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const MenuIcon(Icons.close),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: '餐厅管理',
            icon: const MenuIcon(Icons.more_horiz),
            enabled: !_saving,
            onSelected: (value) => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => value == 'photos'
                    ? PhotoImportPage(restaurantId: r.id)
                    : RestaurantDishesPage(restaurantId: r.id),
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'dishes', child: Text('管理菜品资料')),
              PopupMenuItem(value: 'photos', child: Text('从照片新增用餐记录')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                r.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  [
                    if (r.category.isNotEmpty) r.category,
                    r.averageCost > 0 ? '人均 ¥${money(r.averageCost)}' : '未记录人均',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final address in r.addresses)
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        address,
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ),
                    IconButton(
                      tooltip: '复制地址',
                      icon: const MenuIcon(Icons.copy, size: 19),
                      onPressed: () => performAction(
                        context,
                        () => Clipboard.setData(ClipboardData(text: address)),
                        success: '地址已复制',
                      ),
                    ),
                  ],
                ),
              if (r.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SelectableText(
                    r.note,
                    style: const TextStyle(height: 1.7),
                  ),
                ),
              if (r.link.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => performAction(
                      context,
                      () => Clipboard.setData(ClipboardData(text: r.link)),
                      success: '链接已复制',
                    ),
                    icon: const MenuIcon(Icons.link, size: 17),
                    label: const Text('复制餐厅链接'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              await performAction(
                                context,
                                () => store.update((d) {
                                  final item = d.restaurants.firstWhere(
                                    (v) => v.id == r.id,
                                  );
                                  item.favorite = !item.favorite;
                                }),
                                success: r.favorite ? '已取消收藏' : '已收藏餐厅',
                              );
                              if (mounted) setState(() => _saving = false);
                            },
                      icon: MenuIcon(
                        r.favorite ? Icons.favorite : Icons.favorite_border,
                        size: 19,
                      ),
                      label: Text(r.favorite ? '已收藏' : '收藏'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => editRestaurant(context, restaurant: r),
                      icon: const MenuIcon(Icons.edit_note, size: 19),
                      label: const Text('编辑餐厅'),
                    ),
                  ],
                ),
              ),
              Text(
                '消费记录 · ${records.length} 次',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      MenuIcon(Icons.edit_note, size: 36),
                      SizedBox(height: 14),
                      Text('还没有用餐记录', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      Text('记下吃过的菜和感受，下次再来更好选。', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              for (final visit in records)
                RestaurantVisitCard(restaurant: r, visit: visit),
              TextButton(
                onPressed: _saving ? null : () => _delete(r),
                child: const Text(
                  '删除餐厅',
                  style: TextStyle(color: Color(0xffdc3636)),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FixedPageActions(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving ? null : () => editRestaurantVisit(context, r),
              icon: const MenuIcon(Icons.add, size: 22),
              label: const Text('记一笔'),
            ),
          ),
        ],
      ),
    );
  }
}
