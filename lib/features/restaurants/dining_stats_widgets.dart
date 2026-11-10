import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_currency_picker.dart';
import 'dining_statistics.dart';

class DiningChartCard extends StatelessWidget {
  const DiningChartCard({
    super.key,
    required this.title,
    required this.onDetails,
    this.headerAction,
    this.badge,
    required this.children,
  });
  final String title;
  final VoidCallback onDetails;
  final Widget? headerAction;
  final String? badge;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onDetails,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              badge!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          ?headerAction,
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 40,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '详情',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class DiningBarChart extends StatelessWidget {
  const DiningBarChart({
    super.key,
    required this.groups,
    required this.onSelected,
    this.showRank = true,
  });
  final List<DiningGroup> groups;
  final ValueChanged<DiningGroup> onSelected;
  final bool showRank;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maximum = groups.fold<int>(
      0,
      (value, group) => group.count > value ? group.count : value,
    );
    final countStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: 12,
        color: colors.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final countMeasure = TextPainter(
      text: TextSpan(
        text: '$maximum ${groups.isEmpty ? '次' : groups.first.unit}',
        style: countStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final countWidth = countMeasure.width.ceilToDouble() + 4;
    countMeasure.dispose();
    return Column(
      children: [
        for (final (index, group) in groups.indexed)
          Semantics(
            label:
                '${showRank ? '第${index + 1}名，' : ''}${group.label}，${group.count}${group.unit}',
            button: group.count > 0,
            excludeSemantics: true,
            onTap: group.count == 0 ? null : () => onSelected(group),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: group.count == 0 ? null : () => onSelected(group),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    if (showRank)
                      DiningRankBadge(
                        rank: index + 1,
                        highlighted: index < 3,
                        compact: true,
                      ),
                    if (showRank) const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                            if (group.detail.isNotEmpty)
                              Text(
                                group.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 7,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: ColoredBox(
                          color: colors.primary.withValues(alpha: .07),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: maximum == 0
                                  ? 0
                                  : group.count / maximum,
                              child: SizedBox(
                                height: 6,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(
                                      alpha: switch (index) {
                                        0 => 1,
                                        1 => .85,
                                        2 => .7,
                                        _ => .55,
                                      },
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: countWidth,
                      child: Text(
                        '${group.count} ${group.unit}',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        softWrap: false,
                        style: countStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class DiningCurrencyButton extends StatelessWidget {
  const DiningCurrencyButton({
    super.key,
    required this.currency,
    required this.onChanged,
  });
  final MenuCurrency currency;
  final ValueChanged<MenuCurrency> onChanged;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      textStyle: const TextStyle(fontSize: 15),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(40, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: () async {
      final selected = await selectMenuCurrency(context, currency);
      if (selected != null) onChanged(selected);
    },
    child: Text(
      currency == MenuCurrency.cny ? '￥' : currency.symbol,
      semanticsLabel: '切换币种，当前${currency.label}',
    ),
  );
}

class DiningRankBadge extends StatelessWidget {
  const DiningRankBadge({
    super.key,
    required this.rank,
    required this.highlighted,
    this.compact = false,
  });

  final int rank;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: compact ? 24 : 28,
      child: Align(
        alignment: compact ? Alignment.centerLeft : Alignment.center,
        child: Container(
          width: compact ? 20 : 26,
          height: compact ? 20 : 26,
          alignment: Alignment.center,
          decoration: highlighted
              ? BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: compact ? 11 : 14,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: highlighted ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
