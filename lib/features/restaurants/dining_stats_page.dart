import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'dining_statistics.dart';
import 'dining_stats_details.dart';
import 'dining_stats_widgets.dart';
import 'dining_amount_chart.dart';
import 'restaurants_page.dart';

class DiningStatsPage extends StatefulWidget {
  const DiningStatsPage({super.key});

  @override
  State<DiningStatsPage> createState() => _DiningStatsPageState();
}

class _DiningStatsPageState extends State<DiningStatsPage> {
  MenuCurrency _currency = MenuCurrency.cny;

  Future<void> _details(DiningBreakdown kind) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            DiningStatsDetails(kind: kind, initialCurrency: _currency),
      ),
    );
  }

  void _select(DiningBreakdown kind, DiningGroup group) => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => RestaurantsPage.filtered(
        query: diningGroupFilter(kind, group, _currency),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final stats = DiningStatistics(MenuScope.of(context).data.restaurants);
    final companions = stats.groups(DiningBreakdown.companions, _currency);
    final cuisines = stats.groups(DiningBreakdown.cuisines, _currency);
    final amounts = stats.groups(DiningBreakdown.amounts, _currency);
    final counties = stats.groups(DiningBreakdown.counties, _currency);
    final quarters = stats.groups(
      DiningBreakdown.quarters,
      _currency,
      recentPeriods: 6,
    );
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: MenuScrollTitle(child: const Text('用餐统计'))),
      body: stats.entries.isEmpty
          ? EmptyState(
              icon: Icons.bar_chart_outlined,
              title: '还没有用餐记录',
              message: '记下在餐厅的消费，就能查看饭搭子、菜系、区县和人均价格分布。',
              actionLabel: '返回餐厅',
              onAction: () => Navigator.pop(context),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  primary: true,
                  key: const PageStorageKey('dining-statistics'),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                  children: [
                    _Overview(stats: stats, currency: _currency),
                    DiningChartCard(
                      title: '菜系',
                      badge: 'TOP10',
                      onDetails: () => _details(DiningBreakdown.cuisines),
                      children: [
                        DiningBarChart(
                          groups: cuisines.take(10).toList(),
                          onSelected: (group) =>
                              _select(DiningBreakdown.cuisines, group),
                        ),
                      ],
                    ),
                    DiningChartCard(
                      title: '人均消费',
                      onDetails: () => _details(DiningBreakdown.amounts),
                      headerAction: DiningCurrencyButton(
                        currency: _currency,
                        onChanged: (value) => setState(() => _currency = value),
                      ),
                      children: [
                        if (amounts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 16,
                            ),
                            child: Text(
                              '暂无${_currency.label}消费记录，可切换币种查看。',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          )
                        else
                          DiningAmountChart(
                            groups: amounts,
                            onSelected: (group) =>
                                _select(DiningBreakdown.amounts, group),
                          ),
                      ],
                    ),
                    DiningChartCard(
                      title: '区县',
                      badge: 'TOP10',
                      onDetails: () => _details(DiningBreakdown.counties),
                      children: [
                        DiningBarChart(
                          groups: counties.take(10).toList(),
                          onSelected: (group) =>
                              _select(DiningBreakdown.counties, group),
                        ),
                      ],
                    ),
                    DiningChartCard(
                      title: '消费次数',
                      badge: '最近6个季度',
                      onDetails: () => _details(DiningBreakdown.quarters),
                      children: [
                        DiningAmountChart(
                          groups: quarters.reversed.toList(),
                          labelBuilder: (group) {
                            final date = group.start!;
                            final year = (date.year % 100).toString().padLeft(
                              2,
                              '0',
                            );
                            return '${year}Q${(date.month - 1) ~/ 3 + 1}';
                          },
                          onSelected: (group) =>
                              _select(DiningBreakdown.quarters, group),
                        ),
                      ],
                    ),
                    DiningChartCard(
                      title: '饭搭子',
                      badge: 'TOP10',
                      onDetails: () => _details(DiningBreakdown.companions),
                      children: [
                        if (companions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            child: Text(
                              '还没有填写饭搭子',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          )
                        else
                          DiningBarChart(
                            groups: companions.take(10).toList(),
                            onSelected: (group) =>
                                _select(DiningBreakdown.companions, group),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.stats, required this.currency});
  final DiningStatistics stats;
  final MenuCurrency currency;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final average = stats.averageCost(currency);
    final metrics = [
      ('用餐总数', '', '${stats.entries.length}', '次'),
      (
        '月均用餐',
        '',
        stats.averageVisitsPerPeriod(DiningTimeUnit.month).toStringAsFixed(1),
        '次',
      ),
      (
        '综合人均',
        average == null ? '' : currency.symbol,
        average == null ? '—' : '${average.round()}',
        '',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, prefix, value, unit) in metrics)
                    Expanded(
                      child: Column(
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                if (prefix.isNotEmpty)
                                  TextSpan(
                                    text: prefix,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                TextSpan(text: value),
                                if (unit.isNotEmpty)
                                  TextSpan(
                                    text: ' $unit',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
