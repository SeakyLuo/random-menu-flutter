import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_pill_tabs.dart';
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

class _DiningStatsDetailsState extends State<DiningStatsDetails>
    with SingleTickerProviderStateMixin {
  late MenuCurrency _currency = widget.initialCurrency;
  bool _showRatio = false;
  final _expandedCuisines = <String>{};
  DiningTimeUnit _timeUnit = DiningTimeUnit.quarter;
  RestaurantRegionLevel _regionLevel = RestaurantRegionLevel.county;

  final _scrollControllers = List.generate(3, (_) => ScrollController());

  int get _pageIndex => switch (widget.kind) {
    DiningBreakdown.counties => _regionLevel.index,
    DiningBreakdown.quarters => _timeUnit.index,
    _ => 0,
  };

  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: switch (widget.kind) {
        DiningBreakdown.counties || DiningBreakdown.quarters => 3,
        _ => 1,
      },
      initialIndex: _pageIndex,
      vsync: this,
    )..addListener(_tabChanged);
  }

  void _tabChanged() {
    if (_tabs.index == _pageIndex) return;
    setState(() {
      switch (widget.kind) {
        case DiningBreakdown.counties:
          _regionLevel = RestaurantRegionLevel.values[_tabs.index];
        case DiningBreakdown.quarters:
          _timeUnit = DiningTimeUnit.values[_tabs.index];
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
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
            label: _showRatio
                ? '按占比，点击切换为按${widget.kind == DiningBreakdown.cuisines ? '家数' : '次数'}'
                : '按${widget.kind == DiningBreakdown.cuisines ? '家数' : '次数'}，点击切换为按占比',
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
                        _showRatio
                            ? '按占比'
                            : widget.kind == DiningBreakdown.cuisines
                            ? '按数量'
                            : '按次数',
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
                MenuPillTabs(
                  controller: _tabs,
                  tabs: [
                    for (final label in switch (widget.kind) {
                      DiningBreakdown.counties => ['省', '市', '区县'],
                      DiningBreakdown.quarters => ['年', '季度', '月'],
                      _ => <String>[],
                    })
                      Tab(
                        height: 38,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(label),
                        ),
                      ),
                  ],
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
                        onChanged: (index) => _tabs.animateTo(index),
                        children: [
                          for (var index = 0; index < _tabs.length; index++)
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
    final cuisineStats = widget.kind == DiningBreakdown.cuisines;
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
    final children = <String, List<DiningGroup>>{};
    if (cuisineStats) {
      for (final group in stats.groups(
        DiningBreakdown.cuisines,
        _currency,
        detailedTags: true,
      )) {
        final parent = group.key.substring(0, group.key.lastIndexOf('/'));
        children.putIfAbsent(parent, () => []).add(group);
      }
    }
    final rows = <(DiningGroup, int, int?)>[];
    void addRow(DiningGroup group, int depth, int? rank) {
      rows.add((group, depth, rank));
      if (_expandedCuisines.contains(group.key)) {
        for (final child in children[group.key] ?? <DiningGroup>[]) {
          addRow(child, depth + 1, null);
        }
        if (children.containsKey(group.key)) {
          final other = group.entries
              .where((entry) => entry.restaurant.categories.contains(group.key))
              .toList();
          if (other.isNotEmpty) {
            rows.add((
              DiningGroup(
                group.key,
                '其他',
                other,
                exactCuisine: true,
                countRestaurants: true,
              ),
              depth + 1,
              null,
            ));
          }
        }
      }
    }

    for (final (position, group) in groups.indexed) {
      final alone = companionStats && group.key.isEmpty;
      addRow(
        group,
        0,
        alone
            ? null
            : companionStats
            ? position
            : position + 1,
      );
    }
    final total = amountStats
        ? groups.fold<int>(0, (sum, group) => sum + group.count)
        : cuisineStats
        ? stats.restaurantCount
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
            itemCount: rows.length,
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
              final (group, depth, rank) = rows[index];
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
                key: ValueKey((group.key, group.exactCuisine)),
                color: colors.surface,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(18) : Radius.zero,
                  bottom: index == rows.length - 1
                      ? const Radius.circular(18)
                      : Radius.zero,
                ),
                clipBehavior: Clip.antiAlias,
                child: _RankingRow(
                  group: group,
                  value: _showRatio
                      ? (group.count / total * 100).toStringAsFixed(1)
                      : '${group.count}',
                  unit: _showRatio ? '%' : ' ${group.unit}',
                  label: amountStats
                      ? '${_currency.symbol}${group.label}'
                      : group.label,
                  rank: rank,
                  showRank: !quarterStats && depth == 0,
                  reserveRankSpace: cuisineStats && depth > 0,
                  expanded: _expandedCuisines.contains(group.key),
                  onExpand:
                      !group.exactCuisine && children.containsKey(group.key)
                      ? () => setState(() {
                          if (!_expandedCuisines.add(group.key)) {
                            _expandedCuisines.remove(group.key);
                          }
                        })
                      : null,
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
    this.onExpand,
    this.expanded = false,
    this.reserveRankSpace = false,
  });

  final DiningGroup group;
  final String value, unit;
  final String label;
  final int? rank;
  final bool showRank;
  final bool highlighted;
  final Color barColor;
  final double fraction;
  final VoidCallback? onTap, onExpand;
  final bool expanded;
  final bool reserveRankSpace;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '${!showRank || rank == null ? '' : '$rank，'}$label，${group.detail}，${group.count}${group.unit}',
      button: onTap != null,
      excludeSemantics: onExpand == null,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (showRank || reserveRankSpace)
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: !showRank
                          ? null
                          : rank == null
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
                if (showRank || reserveRankSpace) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
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
                          Text.rich(
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
                  width: 20,
                  child: onExpand != null
                      ? Semantics(
                          button: true,
                          label: '${expanded ? '收起' : '展开'}$label细分',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onExpand,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: AnimatedRotation(
                                turns: expanded ? .5 : 0,
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 200),
                                curve: Curves.easeInOutCubic,
                                child: MenuIcon(
                                  Icons.expand_more,
                                  size: 18,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        )
                      : onTap == null
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
