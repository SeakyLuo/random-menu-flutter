import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/photo_widget.dart';
import 'visit_dish_sheet.dart';
import 'restaurant_food_summary.dart';

class VisitFoodList extends StatelessWidget {
  const VisitFoodList({
    super.key,
    required this.restaurantId,
    required this.visitId,
    required this.items,
    required this.packages,
    required this.vertical,
  });

  final String restaurantId;
  final String visitId;
  final List<VisitDish> items;
  final List<VisitPackage> packages;
  VisitPackage? packageFor(VisitDish dish) => dish.packageId == null
      ? null
      : packages.firstWhere((p) => p.id == dish.packageId);
  final bool vertical;

  String _price(VisitDish dish) =>
      '¥${money(dish.price)}${dish.quantity > 1 ? ' × ${dish.quantity}' : ''}';

  Widget _image(BuildContext context, VisitDish dish, double width) => SizedBox(
    width: width,
    height: vertical ? 78 : 84,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: dish.imagePaths.isEmpty
          ? ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Center(
                child: MenuIcon(
                  Icons.ramen_dining_outlined,
                  size: 28,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : LocalPhoto(path: dish.imagePaths.first),
    ),
  );

  Widget _fields(BuildContext context, VisitDish dish) {
    final package = packageFor(dish);
    final summary = restaurantFoodSummary(dish, package: package);
    final secondaryStyle = TextStyle(
      fontSize: vertical ? 14 : 12,
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  dish.name.isEmpty ? '未命名菜品' : dish.name,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (package == null) ...[
                const SizedBox(width: 8),
                Text(
                  _price(dish),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ],
            ],
          ),
          if (dish.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('“${dish.note}”', style: secondaryStyle),
          ] else if (package != null) ...[
            const SizedBox(height: 4),
            Text(visitPackageLabel(package), style: secondaryStyle),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          dish.name.isEmpty ? '未命名菜品' : dish.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (summary.isNotEmpty)
          Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: secondaryStyle,
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, VisitDish dish, double width) => InkWell(
    borderRadius: BorderRadius.circular(9),
    onTap: () => showVisitDishDetail(
      context,
      restaurantId: restaurantId,
      visitId: visitId,
      itemIndex: items.indexOf(dish),
    ),
    child: vertical
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _image(context, dish, 104),
              const SizedBox(width: 12),
              Expanded(child: _fields(context, dish)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _image(context, dish, width),
              const SizedBox(height: 6),
              _fields(context, dish),
            ],
          ),
  );

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _tile(context, items[i], 104),
          ],
        ],
      );
    }
    final scaler = MediaQuery.textScalerOf(context);
    final width = math.max(110.0, scaler.scale(84));
    double textHeight(
      String text,
      double size,
      double height,
      FontWeight weight,
    ) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(
            context,
          ).style.copyWith(fontSize: size, height: height, fontWeight: weight),
        ),
        maxLines: 1,
        textScaler: scaler,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: width);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final height = items.fold<double>(
      0,
      (height, dish) => math.max(
        height,
        90 +
            textHeight(dish.name, 13, 1.4, FontWeight.w500) +
            (restaurantFoodSummary(dish, package: packageFor(dish)).isNotEmpty
                ? textHeight(
                    restaurantFoodSummary(dish, package: packageFor(dish)),
                    12,
                    1.5,
                    FontWeight.w400,
                  )
                : 0),
      ),
    );
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) =>
            SizedBox(width: width, child: _tile(context, items[index], width)),
      ),
    );
  }
}
