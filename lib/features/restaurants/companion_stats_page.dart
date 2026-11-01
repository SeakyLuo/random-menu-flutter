import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import 'restaurant_detail_page.dart';
import 'restaurant_filter.dart';

class CompanionStatsPage extends StatelessWidget {
  const CompanionStatsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final restaurants = MenuScope.of(context).data.restaurants;
    final counts = <String, int>{'': 0};
    final shops = <String, Set<String>>{'': {}};
    for (final restaurant in restaurants) {
      for (final visit in restaurant.records) {
        final names = visit.companions.isEmpty
            ? <String>{''}
            : visit.companions.toSet();
        for (final name in names) {
          counts.update(name, (count) => count + 1, ifAbsent: () => 1);
          shops.putIfAbsent(name, () => {}).add(restaurant.id);
        }
      }
    }
    final people = counts.keys.where((name) => name.isNotEmpty).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return Scaffold(
      appBar: AppBar(title: const Text('同行人统计')),
      body: counts.values.every((count) => count == 0)
          ? const EmptyState(
              icon: Icons.people_outline,
              title: '还没有约饭记录',
              message: '在餐厅详情记录一次用餐，留下同行人的名字。',
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '按用餐记录统计，独自用餐单独计算。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final person in ['', ...people])
                  Builder(
                    builder: (context) {
                      final count = counts[person]!;
                      final shopCount = shops[person]!.length;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: MenuIcon(
                          person.isEmpty
                              ? Icons.person_outline
                              : Icons.people_outline,
                        ),
                        title: Text(person.isEmpty ? '独自用餐' : person),
                        subtitle: Text('$count 次用餐 · $shopCount 家餐厅'),
                        trailing: count == 0
                            ? null
                            : const MenuIcon(Icons.chevron_right),
                        onTap: count == 0
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      _CompanionRestaurantsPage(person: person),
                                ),
                              ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

class _CompanionRestaurantsPage extends StatelessWidget {
  const _CompanionRestaurantsPage({required this.person});
  final String person;
  @override
  Widget build(BuildContext context) {
    final query = RestaurantQuery(
      alone: person.isEmpty,
      companions: person.isEmpty ? {} : {person},
    );
    final restaurants = MenuScope.of(
      context,
    ).data.restaurants.where(query.matches).toList();
    final visits = restaurants.fold(
      0,
      (sum, r) => sum + r.records.where((v) => query.matchesVisit(r, v)).length,
    );
    return Scaffold(
      appBar: AppBar(title: Text(person.isEmpty ? '独自用餐' : '和$person约饭')),
      body: restaurants.isEmpty
          ? const EmptyState(
              icon: Icons.storefront_outlined,
              title: '还没有相关餐厅',
              message: '添加新的用餐记录后，会在这里汇总。',
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '$visits 次用餐 · ${restaurants.length} 家餐厅',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                for (final r in restaurants)
                  Card(
                    child: ListTile(
                      title: Text(r.name),
                      subtitle: Text(
                        '${r.records.where((v) => query.matchesVisit(r, v)).length} 次相关用餐',
                      ),
                      trailing: const MenuIcon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RestaurantDetailPage(
                            restaurantId: r.id,
                            query: query,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
