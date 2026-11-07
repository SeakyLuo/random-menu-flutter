import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import 'restaurant_entries.dart';
import 'visit_detail_page.dart';

class RestaurantVisitCard extends StatelessWidget {
  const RestaurantVisitCard({
    super.key,
    required this.restaurant,
    required this.visit,
  });
  final Restaurant restaurant;
  final Visit visit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => VisitDetailPage(
                restaurantId: restaurant.id,
                visitId: visit.id,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dayLabel(visit.date).replaceAll('-', '.'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${visit.companions.length + 1} 人',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                visit.totalCost > 0 ? '¥${money(visit.totalCost)}' : '金额未记录',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (visit.address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              visit.address,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (visit.companions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '饭搭子 · ${visit.companions.join('、')}',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (visit.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(visit.note, style: const TextStyle(height: 1.6)),
          ),
        for (final food in visit.items)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 68,
                  height: 68,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: food.imagePaths.isEmpty
                        ? ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .08),
                            child: const Center(
                              child: MenuIcon(
                                Icons.soup_kitchen_outlined,
                                size: 28,
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () => showPhotoViewer(
                              context,
                              food.imagePaths,
                              0,
                              title: food.name,
                              heroTagForIndex: (i) =>
                                  i == 0 ? (context, food) : null,
                            ),
                            child: Hero(
                              tag: (context, food),
                              child: LocalPhoto(path: food.imagePaths.first),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (food.note.isNotEmpty)
                        Text(
                          food.note,
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      Text(
                        '数量 ${food.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (food.imagePaths.length > 1)
                        TextButton(
                          onPressed: () => showPhotoViewer(
                            context,
                            food.imagePaths,
                            0,
                            title: food.name,
                            heroTagForIndex: (i) =>
                                i == 0 ? (context, food) : null,
                          ),
                          child: Text('查看 ${food.imagePaths.length} 张照片'),
                        ),
                    ],
                  ),
                ),
                if (food.price > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '¥${money(food.price)} / 份',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        if (visit.items.isEmpty && visit.dishes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(visit.dishes.join('、')),
          ),
        if (visit.imagePaths.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 14),
              scrollDirection: Axis.horizontal,
              itemCount: visit.imagePaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (_, index) => SizedBox(
                width: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: GestureDetector(
                    onTap: () => showPhotoViewer(
                      context,
                      visit.imagePaths,
                      index,
                      title: '用餐环境',
                      heroTagForIndex: (i) => (context, 'environment', i),
                    ),
                    child: Hero(
                      tag: (context, 'environment', index),
                      child: LocalPhoto(path: visit.imagePaths[index]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () =>
                  editRestaurantVisit(context, restaurant, visit: visit),
              icon: const MenuIcon(Icons.edit_note, size: 17),
              label: const Text('编辑记录'),
            ),
            TextButton(
              onPressed: () =>
                  removeRestaurantVisit(context, restaurant.id, visit),
              child: const Text(
                '删除',
                style: TextStyle(color: Color(0xffdc3636)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
