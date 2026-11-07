import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import 'restaurant_filter.dart';

class CompanionStatsPage extends StatefulWidget {
  const CompanionStatsPage({super.key, this.initialOffset = 0, this.onOffset});
  final double initialOffset;
  final ValueChanged<double>? onOffset;
  @override
  State<CompanionStatsPage> createState() => _CompanionStatsPageState();
}

class _CompanionStatsPageState extends State<CompanionStatsPage> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: widget.initialOffset,
  )..addListener(() => widget.onOffset?.call(_scroll.offset));
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{'': 0};
    for (final restaurant in MenuScope.of(context).data.restaurants) {
      for (final visit in restaurant.records) {
        final names = visit.companions.isEmpty
            ? <String>{''}
            : visit.companions.toSet();
        for (final name in names) {
          counts.update(name, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }
    final names = counts.keys.where((name) => name.isNotEmpty).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final ranks = ['', ...names];
    return Scaffold(
      appBar: AppBar(title: const Text('和谁约饭最多')),
      body: counts.values.every((v) => v == 0)
          ? EmptyState(
              icon: Icons.people_outline,
              title: '还没有约饭记录',
              message: '在餐厅详情记一笔用餐，留下饭搭子的名字。',
              actionLabel: '返回餐厅',
              onAction: () => Navigator.pop(context),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: ranks.length,
                  itemBuilder: (context, index) {
                    final name = ranks[index];
                    final count = counts[name]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(2),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          minTileHeight: 48,
                          minVerticalPadding: 12,
                          minLeadingWidth: 28,
                          horizontalTitleGap: 12,
                          leading: SizedBox(
                            width: 28,
                            child: Center(
                              child: name.isEmpty
                                  ? const MenuIcon(
                                      Icons.person_outline,
                                      size: 18,
                                    )
                                  : Text(
                                      '$index',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            name.isEmpty ? '独自用餐' : name,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$count',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(' 次', style: TextStyle(fontSize: 12)),
                              if (count > 0)
                                const MenuIcon(Icons.chevron_right, size: 17),
                            ],
                          ),
                          onTap: count == 0
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  RestaurantQuery(
                                    alone: name.isEmpty,
                                    companionsOnly: name.isNotEmpty,
                                    companions: name.isEmpty ? {} : {name},
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
