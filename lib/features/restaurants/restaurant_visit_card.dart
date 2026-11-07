import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import 'restaurant_gallery_data.dart';
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date =
        '${visit.date.year}.${visit.date.month.toString().padLeft(2, '0')}.${visit.date.day.toString().padLeft(2, '0')}';
    final scaler = MediaQuery.textScalerOf(context);
    final foodWidth = math.max(110.0, scaler.scale(84));
    String priceLabel(VisitDish dish) => [
      if (dish.price > 0) '¥${money(dish.price)}',
      if (dish.quantity > 1) '${dish.quantity} 份',
    ].join(' · ');
    double textHeight(
      String text,
      double size,
      double height, {
      FontWeight? weight,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(
            context,
          ).style.copyWith(fontSize: size, height: height, fontWeight: weight),
        ),
        maxLines: 2,
        textScaler: scaler,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: foodWidth);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final foodHeight = visit.items.fold<double>(
      0,
      (height, dish) => math.max(
        height,
        90 +
            textHeight(dish.name, 13, 1.4, weight: FontWeight.w500) +
            (dish.note.isNotEmpty ? textHeight(dish.note, 12, 1.5) : 0) +
            (priceLabel(dish).isNotEmpty
                ? textHeight(priceLabel(dish), 12, 1.4)
                : 0),
      ),
    );
    Widget detailLine(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: MenuIcon(icon, size: 15, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                VisitDetailPage(restaurantId: restaurant.id, visitId: visit.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${visit.companions.length + 1} 人',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    visit.totalCost > 0
                        ? '¥${money(visit.totalCost)}'
                        : '金额未记录',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (visit.address.isNotEmpty)
                detailLine(
                  Icons.place_outlined,
                  localAddressText(visit.address),
                ),
              if (visit.companions.isNotEmpty)
                detailLine(Icons.people_outline, visit.companions.join('、')),
              if (visit.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    visit.note,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              if (visit.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: foodHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visit.items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final dish = visit.items[index];
                        return SizedBox(
                          width: foodWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 84,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: dish.imagePaths.isEmpty
                                      ? ColoredBox(
                                          color: colors.surfaceContainer,
                                          child: Center(
                                            child: MenuIcon(
                                              Icons.ramen_dining_outlined,
                                              size: 28,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: () => showPhotoViewer(
                                            context,
                                            dish.imagePaths,
                                            0,
                                            title: dish.name,
                                          ),
                                          child: LocalPhoto(
                                            path: dish.imagePaths.first,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dish.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (dish.note.isNotEmpty)
                                Text(
                                  dish.note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              if (dish.price > 0 || dish.quantity > 1)
                                Text(
                                  priceLabel(dish),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (visit.items.isEmpty && visit.dishes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    visit.dishes.join('、'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
