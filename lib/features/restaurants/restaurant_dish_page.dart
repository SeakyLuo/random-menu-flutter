import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import 'restaurant_dish_summary.dart';
import 'restaurant_entries.dart';
import 'visit_detail_page.dart';

class RestaurantDishPage extends StatefulWidget {
  const RestaurantDishPage({
    super.key,
    required this.restaurantId,
    required this.name,
    this.savedDishId,
  });
  final String restaurantId;
  final String name;
  final String? savedDishId;
  @override
  State<RestaurantDishPage> createState() => _RestaurantDishPageState();
}

class _RestaurantDishPageState extends State<RestaurantDishPage> {
  late String? _savedId = widget.savedDishId;
  final _photos = PageController();
  int _photo = 0;
  late Restaurant _restaurant;
  RestaurantDishSummary? _dish;
  List<String> _paths = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restaurant = MenuScope.of(
      context,
    ).data.restaurants.firstWhere((r) => r.id == widget.restaurantId);
    final name = _savedId == null
        ? widget.name
        : _restaurant.foods.firstWhere((dish) => dish.id == _savedId).name;
    _dish = restaurantDishSummaries(
      _restaurant,
    ).where((dish) => dish.name == name).firstOrNull;
    final paths = _dish?.paths ?? const <String>[];
    if (!listEquals(_paths, paths)) {
      _paths = List.of(paths);
      _photo = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _photos.hasClients) _photos.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = _restaurant;
    final dish = _dish;
    if (dish == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('菜品详情'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.pop(context),
            icon: const MenuIcon(Icons.arrow_back),
          ),
        ),
        body: EmptyState(
          icon: Icons.ramen_dining_outlined,
          title: '这道菜已没有记录',
          message: '返回餐厅，继续看看其他菜。',
          actionLabel: '返回餐厅',
          onAction: () => Navigator.pop(context),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(dish.name),
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.pop(context),
          icon: const MenuIcon(Icons.arrow_back),
        ),
        actions: [
          if (dish.saved != null)
            IconButton(
              tooltip: '编辑菜品资料',
              icon: const MenuIcon(Icons.edit_outlined),
              onPressed: () {
                _savedId = dish.saved!.id;
                setState(() => _photo = 0);
                if (_photos.hasClients) _photos.jumpToPage(0);
                editRestaurantDish(context, restaurant, dish: dish.saved);
              },
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (dish.paths.isNotEmpty) ...[
                LayoutBuilder(
                  builder: (context, constraints) => ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: math.min(320, constraints.maxWidth / 1.25),
                      child: PageView.builder(
                        controller: _photos,
                        itemCount: dish.paths.length,
                        onPageChanged: (index) =>
                            setState(() => _photo = index),
                        itemBuilder: (_, index) => GestureDetector(
                          onTap: () => showPhotoViewer(
                            context,
                            dish.paths,
                            index,
                            title: dish.name,
                            heroTagForIndex: (i) => (this, i),
                            onReturnIndex: (i) {
                              setState(() => _photo = i);
                              _photos.jumpToPage(i);
                            },
                          ),
                          child: Hero(
                            tag: (this, index),
                            child: LocalPhoto(path: dish.paths[index]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (dish.paths.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_photo + 1} / ${dish.paths.length}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
              if (dish.price > 0 || dish.visits > 0)
                Text(
                  [
                    if (dish.price > 0) '¥${money(dish.price)}',
                    if (dish.visits > 0) '吃过 ${dish.visits} 次',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              if (dish.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    dish.note,
                    maxLines:
                        dish.history.any((entry) => entry.dish.note.isNotEmpty)
                        ? 2
                        : null,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (dish.saved == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => editRestaurantDish(
                      context,
                      restaurant,
                      initialName: dish.name,
                    ),
                    icon: const MenuIcon(Icons.add, size: 18),
                    label: const Text('添加菜品资料'),
                  ),
                ),
              if (dish.history.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  '吃过的记录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (final entry in dish.history)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      dayLabel(entry.visit.date),
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      [
                        if (entry.dish.price > 0) '¥${money(entry.dish.price)}',
                        if (entry.dish.note.isNotEmpty) entry.dish.note,
                      ].join(' · '),
                      style: const TextStyle(height: 1.6),
                    ),
                    trailing: const MenuIcon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => VisitDetailPage(
                          restaurantId: restaurant.id,
                          visitId: entry.visit.id,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
