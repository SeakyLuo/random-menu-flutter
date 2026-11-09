import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_field_label.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_popup.dart';
import '../../ui/widgets.dart';
import '../media/photo_widget.dart';
import 'restaurant_food_summary.dart';
import 'restaurant_gallery_data.dart';

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
    final nameStyle = const TextStyle(fontSize: 14, height: 1.4);
    final summaryStyle = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: scheme.onSurfaceVariant,
    );
    double textHeight(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        maxLines: 1,
        ellipsis: '…',
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: 124);
      final height = painter.height.ceilToDouble();
      painter.dispose();
      return height;
    }

    double foodHeight(Visit visit) {
      var height = 0.0;
      for (final dish in visit.items) {
        final summary = restaurantFoodSummary(
          dish,
          package: visit.packageFor(dish),
        );
        final measured =
            84 +
            5 +
            textHeight(dish.name.isEmpty ? '未命名菜品' : dish.name, nameStyle) +
            (summary.isEmpty ? 0 : 2 + textHeight(summary, summaryStyle));
        if (measured > height) height = measured;
      }
      return height;
    }

    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuFieldLabel(
          '消费记录',
          minHeight: 44,
          bottomSpacing: 4,
          icon: Icons.receipt_long_outlined,
          trailing: Tooltip(
            message: '添加消费记录，长按从照片快速创建',
            triggerMode: TooltipTriggerMode.manual,
            child: GestureDetector(
              onLongPress: onPhotos,
              child: IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onAdd,
                icon: const MenuIcon(Icons.add, size: 20),
              ),
            ),
          ),
        ),
        if (sorted.isEmpty)
          Text(
            '暂无消费记录',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        for (final visit in sorted)
          Padding(
            key: ValueKey(visit.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Theme.of(context).inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onEdit(visit),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '${dayLabel(visit.date)} ${TimeOfDay.fromDateTime(visit.date).format(context)}',
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          MenuPopupButton<String>(
                            tooltip: '消费记录操作',
                            buttonBuilder: (open) => IconButton(
                              tooltip: '消费记录操作',
                              alignment: Alignment.bottomCenter,
                              padding: const EdgeInsets.only(bottom: 2),
                              constraints: const BoxConstraints.tightFor(
                                width: 32,
                                height: 32,
                              ),
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: open,
                              icon: const MenuIcon(Icons.more_horiz, size: 18),
                            ),
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (visit.address.isNotEmpty) ...[
                            MenuIcon(
                              Icons.place_outlined,
                              size: 15,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              '${visit.address.isEmpty ? '' : '${localAddressText(visit.address)} · '}¥${money(visit.totalCost)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: summaryStyle,
                            ),
                          ),
                        ],
                      ),
                      if (visit.companions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MenuIcon(
                                Icons.people_outline,
                                size: 15,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  visit.companions.join('、'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: summaryStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (visit.items.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: foodHeight(visit),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: visit.items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, index) {
                              final dish = visit.items[index];
                              final summary = restaurantFoodSummary(
                                dish,
                                package: visit.packageFor(dish),
                              );
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
                                        dish.name.isEmpty ? '未命名菜品' : dish.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: nameStyle,
                                      ),
                                      if (summary.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          summary,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: summaryStyle,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
