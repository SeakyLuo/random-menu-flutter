import '../../ui/menu_popup.dart';
import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'restaurant_entries.dart';
import 'restaurant_images.dart';

Future<bool> removeRestaurantVisit(
  BuildContext context,
  String restaurantId,
  Visit visit,
) async {
  final store = MenuScope.of(context);
  if (!await confirmAction(
    context,
    title: '删除用餐记录？',
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
    success: '用餐记录已删除',
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(title: const Text('用餐记录')),
        body: const SizedBox.shrink(),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('用餐记录'),
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
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                r.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${dayLabel(visit.date)} ${TimeOfDay.fromDateTime(visit.date).format(context)}',
              ),
              if (visit.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MenuIcon(Icons.place_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: SelectableText(visit.address)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                '共 ¥${money(visit.totalCost)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${visit.companions.length + 1} 人 · 人均 ¥${money(visit.totalCost / (visit.companions.length + 1))}',
              ),
              const SizedBox(height: 8),
              Text(
                visit.companions.isEmpty
                    ? '独自用餐'
                    : '饭搭子：${visit.companions.join('、')}',
              ),
              if (visit.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(visit.note, style: const TextStyle(height: 1.6)),
                ),
              SectionTitle('本次菜品 · ${visit.items.length}'),
              if (visit.items.isEmpty)
                Text(
                  '这次没有记录菜品。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              for (final item in visit.items)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '¥${money(item.price)} × ${item.quantity} 份 = ¥${money(item.cost)}',
                        ),
                        if (item.note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(item.note),
                          ),
                        if (item.imagePaths.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: RestaurantImages(paths: item.imagePaths),
                          ),
                      ],
                    ),
                  ),
                ),
              if (visit.imagePaths.isNotEmpty) ...[
                SectionTitle('环境照片 · ${visit.imagePaths.length}'),
                RestaurantImages(paths: visit.imagePaths),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
