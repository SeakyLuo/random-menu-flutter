import 'dart:math' as math;
import 'package:flutter/material.dart';

class MenuSegmented<T> extends StatefulWidget {
  const MenuSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool compact;

  @override
  State<MenuSegmented<T>> createState() => _MenuSegmentedState<T>();
}

class _MenuSegmentedState<T> extends State<MenuSegmented<T>> {
  final _scrollController = ScrollController();

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = _scrollController.position;
      final contentWidth =
          position.viewportDimension + position.maxScrollExtent;
      final itemWidth = (contentWidth - 8) / widget.labels.length;
      final index = widget.labels.keys.toList().indexOf(widget.selected);
      final offset =
          (4 + itemWidth * (index + .5) - position.viewportDimension / 2).clamp(
            0.0,
            position.maxScrollExtent,
          );
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(offset);
      } else {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _revealSelected();
  }

  @override
  void didUpdateWidget(covariant MenuSegmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = widget.compact ? 13.0 : 14.0;
    final visualHeight =
        (widget.compact ? 34.0 : 44.0) +
        (scaler.scale(fontSize) - fontSize) * 1.4;
    final height = math.max(44.0, visualHeight);
    final verticalInset = (height - visualHeight) / 2;
    final radius = visualHeight / 2;
    var itemWidth = 44.0;
    for (final label in widget.labels.values) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      itemWidth = math.max(
        itemWidth,
        painter.width + (widget.compact ? 16 : 20),
      );
      painter.dispose();
    }
    final minWidth = itemWidth * widget.labels.length + 8;
    void select(T value) {
      if (value != widget.selected) widget.onChanged(value);
    }

    return LayoutBuilder(
      builder: (context, constraints) => Center(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox(
          width: widget.compact
              ? math.min(constraints.maxWidth, minWidth)
              : constraints.maxWidth,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: widget.compact
                  ? minWidth
                  : math.max(constraints.maxWidth, minWidth),
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    top: verticalInset,
                    bottom: verticalInset,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.compact
                            ? scheme.onSurface.withValues(
                                alpha: dark ? .07 : .035,
                              )
                            : dark
                            ? const Color(0xff1e3027)
                            : const Color(0xffe8eeeb),
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    left: 4,
                    right: 4,
                    top: verticalInset + 4,
                    bottom: verticalInset + 4,
                    child: AnimatedAlign(
                      alignment: Alignment(
                        -1 +
                            2 *
                                widget.labels.keys.toList().indexOf(
                                  widget.selected,
                                ) /
                                (widget.labels.length - 1),
                        0,
                      ),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: FractionallySizedBox(
                        widthFactor: 1 / widget.labels.length,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xff354b3e)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(radius - 4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        for (final scope in widget.labels.keys)
                          Expanded(
                            child: Semantics(
                              selected: scope == widget.selected,
                              inMutuallyExclusiveGroup: true,
                              button: true,
                              onTap: () => select(scope),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                excludeFromSemantics: true,
                                onTap: () => select(scope),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: verticalInset,
                                  ),
                                  child: Material(
                                    type: MaterialType.transparency,
                                    borderRadius: BorderRadius.circular(radius),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      excludeFromSemantics: true,
                                      splashFactory: widget.compact
                                          ? NoSplash.splashFactory
                                          : null,
                                      highlightColor: widget.compact
                                          ? Colors.transparent
                                          : null,
                                      splashColor: widget.compact
                                          ? Colors.transparent
                                          : null,
                                      borderRadius: BorderRadius.circular(
                                        radius,
                                      ),
                                      onTap: () => select(scope),
                                      child: Center(
                                        child: Text(
                                          widget.labels[scope]!,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: fontSize,
                                            fontWeight: scope == widget.selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: scope == widget.selected
                                                ? scheme.primary
                                                : scheme.onSurfaceVariant,
                                          ),
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
