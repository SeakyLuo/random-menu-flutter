import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import 'dining_statistics.dart';
import 'restaurant_visit_card.dart';

class TakeawayRecordsPage extends StatelessWidget {
  const TakeawayRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final records =
        DiningStatistics(
            MenuScope.of(context).data.restaurants,
          ).entries.where((entry) => entry.visit.isTakeaway).toList()
          ..sort((a, b) => b.visit.date.compareTo(a.visit.date));
    return Scaffold(
      appBar: AppBar(
        title: MenuScrollTitle(child: Text('外卖 ${records.length} 次')),
      ),
      body: records.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: '还没有外卖记录',
              message: '在消费记录中勾选“外卖”，就会显示在这里。',
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.separated(
                  primary: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final entry = records[index];
                    return RestaurantVisitCard(
                      key: ValueKey((entry.restaurant.id, entry.visit.id)),
                      restaurant: entry.restaurant,
                      visit: entry.visit,
                      verticalFoods: false,
                      showAddress: true,
                      currentCity: null,
                      showRestaurant: true,
                    );
                  },
                ),
              ),
            ),
    );
  }
}
