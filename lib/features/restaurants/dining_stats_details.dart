import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_segmented.dart';
import '../../ui/retained_tab_view.dart';
import '../../ui/widgets.dart';
import 'dining_statistics.dart';
import 'dining_stats_widgets.dart';
import 'restaurants_page.dart';
import 'restaurant_filter.dart';

class DiningStatsDetails extends StatefulWidget {
  const DiningStatsDetails({
    super.key,
    required this.kind,
    required this.initialCurrency,
  });
  final DiningBreakdown kind;
  final MenuCurrency initialCurrency;

  @override
  State<DiningStatsDetails> createState() => _DiningStatsDetailsState();
}

class _DiningStatsDetailsState extends State<DiningStatsDetails> {
  late MenuCurrency _currency = widget.initialCurrency;
  bool _showRatio = false;
  DiningTimeUnit _timeUnit = DiningTimeUnit.quarter;
  RestaurantRegionLevel _regionLevel = RestaurantRegionLevel.county;

  final _scrollControllers = List.generate(3, (_) => ScrollController());

  int get _pageIndex => switch (widget.kind) {
    DiningBreakdown.counties => _regionLevel.index,
    DiningBreakdown.quarters => _timeUnit.index,
    _ => 0,
  };

  @override
  void dispose() {
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = DiningStatistics(MenuScope.of(context).data.restaurants);
    final companionStats = widget.kind == DiningBreakdown.companions;
    final quarterStats = widget.kind == DiningBreakdown.quarters;
    final amountStats = widget.kind == DiningBreakdown.amounts;
    final regionStats = widget.kind == DiningBreakdown.counties;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: MenuScrollTitle(
          controller: _scrollControllers[_pageIndex],
          child: MenuTitleLine(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(widget.kind.title)),
              if (amountStats)
                DiningCurrencyButton(
                  currency: _currency,
                  onChanged: (value) => setState(() => _currency = value),
                ),
              if (widget.kind == DiningBreakdown.cuisines) ...[
                const SizedBox(width: 10),
                Text(
                  '${stats.cuisineCount} 种',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: _showRatio ? '占比，点击切换为次数' : '次数，点击切换为占比',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showRatio = !_showRatio),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Text(
                        _showRatio ? '占比' : '次数',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (quarterStats || regionStats)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (regionStats)
                        MenuSegmented<RestaurantRegionLevel>(
                          compact: true,
                          labels: const {
                            RestaurantRegionLevel.province: '省',
                            RestaurantRegionLevel.city: '市',
                            RestaurantRegionLevel.county: '区县',
                          },
                          selected: _regionLevel,
                          onChanged: (value) =>
                              setState(() => _regionLevel = value),
                        ),
                      if (quarterStats)
                        MenuSegmented<DiningTimeUnit>(
                          compact: true,
                          labels: const {
                            DiningTimeUnit.year: '年',
                            DiningTimeUnit.quarter: '季度',
                            DiningTimeUnit.month: '月',
                          },
                          selected: _timeUnit,
                          onChanged: (value) =>
                              setState(() => _timeUnit = value),
                        ),
                    ],
                  ),
                ),
              if (_showRatio && companionStats)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '占全部用餐次数；同餐可有多位饭搭子，合计可能超过 100%。',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              Expanded(
                child: quarterStats || regionStats
                    ? RetainedTabView(
                        index: _pageIndex,
                        onChanged: (index) => setState(() {
                          if (regionStats) {
                            _regionLevel = RestaurantRegionLevel.values[index];
                          } else {
                            _timeUnit = DiningTimeUnit.values[index];
                          }
                        }),
                        children: [
                          for (var index = 0; index < 3; index++)
                            _list(context, stats, index),
                        ],
                      )
                    : _list(context, stats, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, DiningStatistics stats, int index) {
    final timeUnit = widget.kind == DiningBreakdown.quarters
        ? DiningTimeUnit.values[index]
        : _timeUnit;
    final regionLevel = widget.kind == DiningBreakdown.counties
        ? RestaurantRegionLevel.values[index]
        : _regionLevel;
    final groups = stats.groups(
      widget.kind,
      _currency,
      amountBands: DiningAmountBand.details,
      timeUnit: timeUnit,
      regionLevel: regionLevel,
    );
    final companionStats = widget.kind == DiningBreakdown.companions;
    final quarterStats = widget.kind == DiningBreakdown.quarters;
    final amountStats = widget.kind == DiningBreakdown.amounts;
    if (companionStats) groups.insert(0, DiningGroup('', '独自用餐', stats.alone));
    final total = amountStats
        ? groups.fold<int>(0, (sum, group) => sum + group.count)
        : stats.entries.length;
    final colors = Theme.of(context).colorScheme;
    final maximum = groups.fold<int>(
      0,
      (value, group) => group.count > value ? group.count : value,
    );
    return groups.every((group) => group.count == 0)
        ? EmptyState(
            icon: Icons.bar_chart_outlined,
            title: amountStats ? '暂无${_currency.label}消费记录' : '暂无统计记录',
            message: amountStats ? '可以切换币种查看其他消费。' : '添加消费记录后，这里会显示完整统计。',
            actionLabel: '返回统计',
            onAction: () => Navigator.pop(context),
          )
        : ListView.separated(
            primary: false,
            controller: _scrollControllers[index],
            key: PageStorageKey(
              'dining-details-${widget.kind.name}-${timeUnit.name}-${regionLevel.name}',
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            itemCount: groups.length,
            separatorBuilder: (_, _) => ColoredBox(
              color: colors.surface,
              child: Divider(
                height: 1,
                thickness: .5,
                indent: 16,
                endIndent: 16,
                color: colors.outlineVariant.withValues(alpha: .35),
              ),
            ),
            itemBuilder: (context, index) {
              final group = groups[index];
              final alone = companionStats && group.key.isEmpty;
              final rank = alone
                  ? null
                  : companionStats
                  ? index
                  : index + 1;
              final highlighted =
                  !amountStats && !quarterStats && rank != null && rank <= 3;
              final barColor = colors.primary.withValues(
                alpha: highlighted
                    ? (rank == 1
                          ? 1
                          : rank == 2
                          ? .85
                          : .7)
                    : .55,
              );
              return Material(
                color: colors.surface,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(18) : Radius.zero,
                  bottom: index == groups.length - 1
                      ? const Radius.circular(18)
                      : Radius.zero,
                ),
                clipBehavior: Clip.antiAlias,
                child: _RankingRow(
                  group: group,
                  value: _showRatio
                      ? (group.count / total * 100).toStringAsFixed(1)
                      : '${group.count}',
                  unit: _showRatio ? '%' : ' 次',
                  label: amountStats
                      ? '${_currency.symbol}${group.label}'
                      : group.label,
                  rank: rank,
                  showRank: !quarterStats,
                  highlighted: highlighted,
                  barColor: barColor,
                  fraction: group.count / maximum,
                  onTap: group.count == 0
                      ? null
                      : () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => RestaurantsPage.filtered(
                              query: diningGroupFilter(
                                widget.kind,
                                group,
                                _currency,
                              ),
                            ),
                          ),
                        ),
                ),
              );
            },
          );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.group,
    required this.value,
    required this.unit,
    required this.label,
    required this.rank,
    required this.showRank,
    required this.highlighted,
    required this.barColor,
    required this.fraction,
    required this.onTap,
  });

  final DiningGroup group;
  final String value, unit;
  final String label;
  final int? rank;
  final bool showRank;
  final bool highlighted;
  final Color barColor;
  final double fraction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '${!showRank || rank == null ? '' : '$rank，'}$label，${group.detail}，${group.count}次',
      button: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (showRank)
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: rank == null
                          ? MenuIcon(
                              Icons.person_outline,
                              size: 18,
                              color: colors.onSurfaceVariant,
                            )
                          : DiningRankBadge(
                              rank: rank!,
                              highlighted: highlighted,
                            ),
                    ),
                  ),
                if (showRank) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: value,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: unit,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: colors.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (group.detail.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            group.detail,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 6,
                          child: ColoredBox(
                            color: colors.primary.withValues(alpha: .07),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FractionallySizedBox(
                                widthFactor: fraction,
                                heightFactor: 1,
                                child: ColoredBox(color: barColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 17,
                  child: onTap == null
                      ? null
                      : MenuIcon(
                          Icons.chevron_right,
                          size: 17,
                          color: colors.onSurfaceVariant,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
