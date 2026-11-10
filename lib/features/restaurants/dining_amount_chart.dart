import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dining_statistics.dart';

class DiningAmountChart extends StatelessWidget {
  const DiningAmountChart({
    super.key,
    required this.groups,
    required this.onSelected,
    this.labelBuilder,
  });

  final List<DiningGroup> groups;
  final ValueChanged<DiningGroup> onSelected;
  final String Function(DiningGroup)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maximum = groups.map((group) => group.count).reduce(math.max);
    final scaler = MediaQuery.textScalerOf(context);
    final labelHeight = scaler.scale(11) * 2.8 + 12;
    final countHeight = scaler.scale(12) * 1.5;
    final plotHeight = 120 + countHeight + 8;
    final minWidth = math.max(48.0, scaler.scale(11) * 4);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(constraints.maxWidth, groups.length * minWidth),
            height: plotHeight + labelHeight,
            child: Stack(
              children: [
                for (final offset in [0.0, 60.0, 120.0])
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: labelHeight + offset,
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.onSurface.withValues(alpha: .06),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final group in groups)
                      Expanded(
                        child: Semantics(
                          label: '${group.label}，${group.count}次',
                          button: group.count > 0,
                          excludeSemantics: true,
                          onTap: group.count == 0
                              ? null
                              : () => onSelected(group),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: group.count == 0
                                ? null
                                : () => onSelected(group),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: plotHeight,
                                  child: LayoutBuilder(
                                    builder: (context, column) {
                                      final height = maximum == 0
                                          ? 0.0
                                          : 120 * group.count / maximum;
                                      return Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          Positioned(
                                            bottom: height + 6,
                                            left: 0,
                                            right: 0,
                                            child: Text(
                                              '${group.count}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              width: math.min(
                                                28,
                                                column.maxWidth * .48,
                                              ),
                                              height: height,
                                              decoration: BoxDecoration(
                                                color: colors.primary
                                                    .withValues(
                                                      alpha:
                                                          group.count == maximum
                                                          ? 1
                                                          : .6,
                                                    ),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(6),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  height: labelHeight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      labelBuilder?.call(group) ??
                                          group.label.replaceFirst('–', '–\n'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.3,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
