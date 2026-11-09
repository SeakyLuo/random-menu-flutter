import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../../ui/menu_popup.dart';
import '../media/media_actions.dart';
import 'restaurant_dish_summary.dart';
import 'visit_detail_page.dart';
import 'restaurant_food_summary.dart';
import 'restaurant_cover_action.dart';

class RestaurantDishPage extends StatefulWidget {
  const RestaurantDishPage({
    super.key,
    required this.restaurantId,
    required this.name,
    this.sourceVisitId,
    this.sourceItemIndex,
  }) : previewDish = null,
       previewPackage = null;
  RestaurantDishPage.preview({
    super.key,
    required VisitDish dish,
    required VisitPackage package,
  }) : restaurantId = '',
       name = dish.name,
       sourceVisitId = null,
       sourceItemIndex = null,
       previewDish = dish,
       previewPackage = package;
  final String restaurantId;
  final String name;
  final String? sourceVisitId;
  final int? sourceItemIndex;
  final VisitDish? previewDish;
  final VisitPackage? previewPackage;
  @override
  State<RestaurantDishPage> createState() => _RestaurantDishPageState();
}

class _RestaurantDishPageState extends State<RestaurantDishPage> {
  final _photos = PageController();
  int _photo = 0;
  bool _savingCover = false;
  RestaurantDishSummary? _dish;
  List<String> _paths = [];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final preview = widget.previewDish;
    if (preview != null) {
      _dish = RestaurantDishSummary(preview.name)
        ..paths.addAll(preview.imagePaths);
    } else {
      final restaurant = MenuScope.of(
        context,
      ).data.restaurants.firstWhere((r) => r.id == widget.restaurantId);
      _dish = restaurantDishSummaries(restaurant, includeNonDishes: true)
          .where(
            (dish) => widget.name.isEmpty
                ? dish.history.first.visit.id == widget.sourceVisitId &&
                      dish.history.first.index == widget.sourceItemIndex
                : dish.name == widget.name,
          )
          .firstOrNull;
    }
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
    final preview = widget.previewDish;
    final package = preview == null ? dish.package : widget.previewPackage;
    final price = preview == null ? dish.price : 0.0;
    final note = preview == null ? dish.note : preview.note;
    final scheme = Theme.of(context).colorScheme;
    final coverDishId = preview == null
        ? MenuScope.of(context).data.restaurants
              .firstWhere((restaurant) => restaurant.id == widget.restaurantId)
              .coverDishId
        : null;
    final isCover = dish.history.any(
      (entry) => entry.dish.dishId == coverDishId,
    );
    final coverSource = dish.history
        .where((entry) => entry.dish.isDish && entry.dish.imagePaths.isNotEmpty)
        .firstOrNull;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(dish.name.isEmpty ? '菜品详情' : dish.name),
        actions: [
          if (preview == null && (coverSource != null || isCover))
            MenuPopupButton<String>(
              tooltip: '菜品操作',
              enabled: !_savingCover,
              onSelected: (_) async {
                setState(() => _savingCover = true);
                await setRestaurantCover(
                  context,
                  widget.restaurantId,
                  isCover ? null : coverSource!.dish.dishId,
                );
                if (mounted) setState(() => _savingCover = false);
              },
              itemBuilder: (_) => [
                MenuPopupItem(
                  value: 'cover',
                  icon: isCover ? Icons.restart_alt : Icons.image_outlined,
                  child: Text(isCover ? '恢复默认封面' : '设为餐厅封面'),
                ),
              ],
            ),
        ],
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.pop(context),
          icon: const MenuIcon(Icons.arrow_back),
        ),
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
              if (price > 0 || dish.visits > 0 || package != null)
                Text(
                  [
                    if (price > 0) '¥${money(price)}',
                    if (note.isEmpty && package != null)
                      visitPackageLabel(package),
                    if (dish.visits > 0) '吃过 ${dish.visits} 次',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    note,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: scheme.onSurfaceVariant,
                    ),
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
                    trailing: const MenuIcon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => VisitDetailPage(
                          restaurantId: widget.restaurantId,
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
