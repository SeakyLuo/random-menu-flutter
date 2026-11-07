import 'dart:math' as math;
import 'package:flutter/material.dart';

class SearchScope<T> extends StatefulWidget {
  const SearchScope({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  State<SearchScope<T>> createState() => _SearchScopeState<T>();
}

class _SearchScopeState<T> extends State<SearchScope<T>> {
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
  void didUpdateWidget(covariant SearchScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scaler = MediaQuery.textScalerOf(context);
    var itemWidth = 44.0;
    for (final label in widget.labels.values) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout();
      itemWidth = math.max(itemWidth, painter.width + 20);
      painter.dispose();
    }
    final minWidth = itemWidth * widget.labels.length + 8;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Container(
          width: math.max(constraints.maxWidth, minWidth),
          height: 44 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 1.4,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: dark ? const Color(0xff1e3027) : const Color(0xffe8eeeb),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                top: 4,
                bottom: 4,
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
                        color: dark ? const Color(0xff354b3e) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final scope in widget.labels.keys)
                    Expanded(
                      child: Semantics(
                        selected: scope == widget.selected,
                        inMutuallyExclusiveGroup: true,
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              if (scope != widget.selected) {
                                widget.onChanged(scope);
                              }
                            },
                            child: Center(
                              child: Text(
                                widget.labels[scope]!,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 14,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
