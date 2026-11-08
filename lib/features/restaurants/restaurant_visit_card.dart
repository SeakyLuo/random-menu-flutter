import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import 'visit_food_list.dart';
import 'restaurant_gallery_data.dart';
import 'visit_detail_page.dart';
import 'restaurant_entries.dart';

class RestaurantVisitCard extends StatelessWidget {
  const RestaurantVisitCard({
    super.key,
    required this.restaurant,
    required this.visit,
    required this.verticalFoods,
    required this.showAddress,
    required this.currentCity,
  });
  final Restaurant restaurant;
  final Visit visit;
  final bool verticalFoods;
  final bool showAddress;
  final String? currentCity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visitCity = restaurant.addressEntries
        .where((address) => address.id == visit.addressId)
        .firstOrNull
        ?.city;
    final addressText = currentCity != null && visitCity == currentCity
        ? localAddressText(visit.address)
        : visit.address;
    final date =
        '${visit.date.year}-${visit.date.month.toString().padLeft(2, '0')}-${visit.date.day.toString().padLeft(2, '0')}';
    final companions = visit.companions.join('、');
    final companionLabel = companions.length < 15
        ? companions
        : '${visit.companions.take(4).join('、')}等${visit.companions.length}人';
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
        onLongPress: () =>
            editRestaurantVisit(context, restaurant, visit: visit),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                VisitDetailPage(restaurantId: restaurant.id, visitId: visit.id),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(verticalFoods ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Text(
                        '总消费：¥${money(visit.totalCost)}',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (visit.companions.isNotEmpty)
                detailLine(Icons.people_outline, companionLabel),
              if (showAddress && visit.address.isNotEmpty)
                detailLine(Icons.place_outlined, addressText),
              if (visit.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '“${visit.note}”',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              if (visit.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: VisitFoodList(
                    restaurantId: restaurant.id,
                    items: visit.items,
                    packages: visit.packages,
                    vertical: verticalFoods,
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
