import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../../ui/menu_icon.dart';

typedef HistoricalDish = ({Visit visit, VisitDish dish});

List<HistoricalDish> historicalDishes(
  Restaurant restaurant,
  DateTime date,
  String? currentVisitId,
) {
  final visits =
      restaurant.records
          .where(
            (visit) => visit.id != currentVisitId && visit.date.isBefore(date),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  final dishes = <String, HistoricalDish>{};
  for (final visit in visits) {
    for (final dish in visit.items) {
      if (dish.isDish && dish.name.isNotEmpty) {
        dishes.putIfAbsent(dish.name, () => (visit: visit, dish: dish));
      }
    }
  }
  return dishes.values.toList();
}

Future<HistoricalDish?> selectHistoricalDish(
  BuildContext context, {
  required List<HistoricalDish> dishes,
  required Set<String> addedNames,
  required MenuCurrency currency,
}) => Navigator.push<HistoricalDish>(
  context,
  MaterialPageRoute(
    builder: (_) => _HistoryDishesPage(
      dishes: dishes,
      addedNames: addedNames,
      currency: currency,
    ),
  ),
);

class _HistoryDishesPage extends StatefulWidget {
  const _HistoryDishesPage({
    required this.dishes,
    required this.addedNames,
    required this.currency,
  });
  final List<HistoricalDish> dishes;
  final Set<String> addedNames;
  final MenuCurrency currency;
  @override
  State<_HistoryDishesPage> createState() => _HistoryDishesPageState();
}

class _HistoryDishesPageState extends State<_HistoryDishesPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final choices = widget.dishes
        .where(
          (entry) =>
              entry.dish.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('从历史消费添加')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: '搜索菜名',
                    prefixIcon: MenuIcon(
                      Icons.search,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: choices.isEmpty
                    ? const EmptyState(
                        icon: Icons.search,
                        title: '没有匹配的菜品',
                        message: '换个菜名搜索。',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: choices.length,
                        itemBuilder: (context, index) {
                          final entry = choices[index];
                          final dish = entry.dish;
                          final added = widget.addedNames.contains(dish.name);
                          final needsPrice =
                              dish.packageId != null ||
                              entry.visit.currency != widget.currency;
                          final price = dish.packageId != null
                              ? '套餐内菜品'
                              : '${entry.visit.currency.symbol}${money(dish.price)}';
                          return ListTile(
                            enabled: !added,
                            title: Text(
                              dish.name,
                              style: const TextStyle(fontSize: 15),
                            ),
                            subtitle: Text(
                              '${dayLabel(entry.visit.date)} · $price${needsPrice ? ' · 需填写本次单价' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            trailing: added
                                ? Text(
                                    '本次已添加',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  )
                                : MenuIcon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: colors.onSurfaceVariant,
                                  ),
                            onTap: added
                                ? null
                                : () => Navigator.pop(context, entry),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
