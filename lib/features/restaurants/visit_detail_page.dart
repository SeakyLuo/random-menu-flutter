import '../../ui/menu_popup.dart';
import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'restaurant_entries.dart';
import '../media/media_actions.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'restaurant_dish_card.dart';
import 'visit_dish_sheet.dart';

Future<bool> removeRestaurantVisit(
  BuildContext context,
  String restaurantId,
  Visit visit,
) async {
  final store = MenuScope.of(context);
  if (!await confirmAction(
    context,
    title: '删除消费记录？',
    message: '删除 ${dayLabel(visit.date)} 的记录及本次菜品明细和照片引用。餐厅菜单仍会保留，记录无法恢复。',
  )) {
    return false;
  }
  if (!context.mounted) return false;
  return performAction(
    context,
    () => store.update(
      MenuWriteScope.restaurant(restaurantId),
      (draft) => draft.restaurants
          .firstWhere((r) => r.id == restaurantId)
          .records
          .removeWhere((v) => v.id == visit.id),
    ),
    success: '消费记录已删除',
  );
}

class VisitDetailPage extends StatelessWidget {
  const VisitDetailPage({
    super.key,
    required this.restaurantId,
    required this.visitId,
  });
  final String restaurantId;
  final String visitId;
  @override
  Widget build(BuildContext context) {
    final r = MenuScope.of(
      context,
    ).data.restaurants.firstWhere((r) => r.id == restaurantId);
    final visit = r.records.where((v) => v.id == visitId).firstOrNull;
    if (visit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('消费记录')),
        body: const SizedBox.shrink(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('消费记录'),
        actions: [
          IconButton(
            tooltip: '编辑记录',
            onPressed: () => editRestaurantVisit(context, r, visit: visit),
            icon: const MenuIcon(Icons.edit_outlined),
          ),
          MenuPopupButton<String>(
            icon: const MenuIcon(Icons.more_horiz),
            tooltip: '记录操作',
            onSelected: (_) async {
              final deleted = await removeRestaurantVisit(
                context,
                restaurantId,
                visit,
              );
              if (deleted && context.mounted) Navigator.pop(context);
            },
            itemBuilder: (_) => const [
              MenuPopupItem(
                icon: Icons.delete_outline,
                destructive: true,
                value: 'delete',
                child: Text('删除记录'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        r.name,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          MenuIcon(
                            Icons.schedule,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${dayLabel(visit.date)} ${TimeOfDay.fromDateTime(visit.date).format(context)}',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '¥${money(visit.totalCost)}',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (visit.address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MenuIcon(
                                Icons.place_outlined,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  visit.address,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (visit.companions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MenuIcon(
                                Icons.people_outline,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  visit.companions.join('、'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (visit.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '“${visit.note}”',
                            style: const TextStyle(fontSize: 14, height: 1.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (visit.imagePaths.isNotEmpty) ...[
                _VisitSectionTitle(
                  '用餐环境',
                  count: '${visit.imagePaths.length} 张',
                ),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visit.imagePaths.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GestureDetector(
                          onTap: () => showPhotoViewer(
                            context,
                            visit.imagePaths,
                            index,
                            title: '用餐环境',
                          ),
                          child: LocalPhoto(path: visit.imagePaths[index]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (visit.packages.isNotEmpty) ...[
                const SectionTitle('本次套餐'),
                for (final package in visit.packages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${package.name} · 套餐总价 ¥${money(package.totalPrice)}',
                    ),
                  ),
              ],
              if (visit.items.isNotEmpty) ...[
                _VisitSectionTitle('本次菜品', count: '${visit.items.length} 道'),
                LayoutBuilder(
                  builder: (context, constraints) => MasonryGridView.count(
                    shrinkWrap: true,
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    crossAxisCount: constraints.maxWidth >= 600 ? 2 : 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 24,
                    itemCount: visit.items.length,
                    itemBuilder: (context, index) {
                      final dish = visit.items[index];
                      return RestaurantDishCard(
                        name: dish.name,
                        paths: dish.imagePaths,
                        price: dish.price,
                        note: dish.note,
                        quantity: dish.quantity,
                        package: visit.packageFor(dish),
                        onTap: () => showVisitDishDetail(
                          context,
                          restaurantId: restaurantId,
                          visitId: visit.id,
                          itemIndex: index,
                        ),
                      );
                    },
                  ),
                ),
              ] else if (visit.dishes.isNotEmpty) ...[
                _VisitSectionTitle('本次菜品', count: '${visit.dishes.length} 道'),
                Text(visit.dishes.join('、')),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisitSectionTitle extends StatelessWidget {
  const _VisitSectionTitle(this.title, {required this.count});

  final String title;
  final String count;

  @override
  Widget build(BuildContext context) => SectionTitle(
    title,
    trailing: Text(
      count,
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
