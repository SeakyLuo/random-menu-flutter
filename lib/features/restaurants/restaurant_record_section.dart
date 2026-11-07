import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_field_label.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_popup.dart';
import '../../ui/widgets.dart';
import '../media/photo_widget.dart';

class RestaurantRecordSection extends StatelessWidget {
  const RestaurantRecordSection({
    super.key,
    required this.records,
    required this.onAdd,
    required this.onPhotos,
    required this.onEdit,
    required this.onDish,
    required this.onRemove,
  });
  final List<Visit> records;
  final VoidCallback onAdd, onPhotos;
  final ValueChanged<Visit> onEdit, onRemove;
  final void Function(Visit, int) onDish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuFieldLabel(
          '消费记录',
          icon: Icons.receipt_long_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '从照片快速创建消费记录',
                onPressed: onPhotos,
                icon: const MenuIcon(
                  Icons.add_photo_alternate_outlined,
                  size: 20,
                ),
              ),
              Tooltip(
                message: '添加消费记录，长按从照片快速创建',
                triggerMode: TooltipTriggerMode.manual,
                child: GestureDetector(
                  onLongPress: onPhotos,
                  child: IconButton(
                    onPressed: onAdd,
                    icon: const MenuIcon(Icons.add, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (sorted.isEmpty)
          TextButton.icon(
            onPressed: onAdd,
            icon: const MenuIcon(Icons.add, size: 18),
            label: const Text('添加一次消费记录'),
          ),
        for (final visit in sorted)
          Padding(
            key: ValueKey(visit.id),
            padding: const EdgeInsets.only(bottom: 16),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onEdit(visit),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${dayLabel(visit.date)} ${TimeOfDay.fromDateTime(visit.date).format(context)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          MenuPopupButton<String>(
                            tooltip: '消费记录操作',
                            icon: const MenuIcon(Icons.more_horiz, size: 20),
                            onSelected: (action) => action == 'edit'
                                ? onEdit(visit)
                                : onRemove(visit),
                            itemBuilder: (_) => const [
                              MenuPopupItem(
                                value: 'edit',
                                icon: Icons.edit_outlined,
                                child: Text('编辑消费记录'),
                              ),
                              MenuPopupItem(
                                value: 'remove',
                                icon: Icons.delete_outline,
                                destructive: true,
                                child: Text('删除消费记录'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '${visit.address.isEmpty ? '' : '${visit.address} · '}${visit.items.length} 道菜 · ¥${money(visit.totalCost)}',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (visit.companions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '同行 · ${visit.companions.join('、')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (visit.items.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height:
                              120 + MediaQuery.textScalerOf(context).scale(28),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: visit.items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, index) {
                              final dish = visit.items[index];
                              return SizedBox(
                                width: 124,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => onDish(visit, index),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          height: 84,
                                          child: dish.imagePaths.isEmpty
                                              ? ColoredBox(
                                                  color: scheme
                                                      .surfaceContainerLow,
                                                  child: Center(
                                                    child: MenuIcon(
                                                      Icons
                                                          .ramen_dining_outlined,
                                                      color: scheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                )
                                              : LocalPhoto(
                                                  path: dish.imagePaths.first,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        dish.name.isEmpty ? '填写菜名' : dish.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                        ),
                                      ),
                                      Text(
                                        '¥${money(dish.price)} × ${dish.quantity} 份',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (visit.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            visit.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
