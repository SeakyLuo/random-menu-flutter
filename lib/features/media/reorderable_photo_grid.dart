import 'package:flutter/material.dart';
import 'photo_widget.dart';

class ReorderablePhotoGrid extends StatefulWidget {
  const ReorderablePhotoGrid({
    super.key,
    required this.paths,
    required this.itemBuilder,
    required this.onReorder,
    this.trailing = const [],
    this.spacing = 8,
    this.runSpacing = 8,
    this.enabled = true,
  });

  final List<String> paths;
  final IndexedWidgetBuilder itemBuilder;
  final void Function(int from, int to) onReorder;
  final List<Widget> trailing;
  final double spacing;
  final double runSpacing;
  final bool enabled;

  @override
  State<ReorderablePhotoGrid> createState() => _ReorderablePhotoGridState();
}

class _PhotoDrag {
  const _PhotoDrag(this.owner, this.index);
  final _ReorderablePhotoGridState owner;
  final int index;
}

class _ReorderablePhotoGridState extends State<ReorderablePhotoGrid> {
  int? dragging;
  EdgeDraggingAutoScroller? autoScroller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    autoScroller?.stopAutoScroll();
    final scrollable = Scrollable.maybeOf(context);
    autoScroller = scrollable == null
        ? null
        : EdgeDraggingAutoScroller(scrollable, velocityScalar: 12);
  }

  @override
  void dispose() {
    autoScroller?.stopAutoScroll();
    super.dispose();
  }

  void finish() {
    autoScroller?.stopAutoScroll();
    if (mounted) setState(() => dragging = null);
  }

  Widget tile(BuildContext context, int index) {
    final child = widget.itemBuilder(context, index);
    if (!widget.enabled || widget.paths.length < 2) return child;
    return DragTarget<_PhotoDrag>(
      onWillAcceptWithDetails: (details) =>
          identical(details.data.owner, this) && details.data.index != index,
      onAcceptWithDetails: (details) =>
          widget.onReorder(details.data.index, index),
      builder: (context, candidates, rejected) =>
          LongPressDraggable<_PhotoDrag>(
            data: _PhotoDrag(this, index),
            maxSimultaneousDrags: 1,
            onDragStarted: () => setState(() => dragging = index),
            onDragUpdate: (details) => autoScroller?.startAutoScrollIfNecessary(
              Rect.fromCenter(
                center: details.globalPosition,
                width: 64,
                height: 80,
              ),
            ),
            onDragEnd: (_) => finish(),
            feedback: Material(
              type: MaterialType.transparency,
              child: SizedBox.square(
                dimension: 96,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LocalPhoto(path: widget.paths[index]),
                ),
              ),
            ),
            child: Opacity(
              opacity: dragging == index ? .25 : 1,
              child: Stack(
                children: [
                  AbsorbPointer(absorbing: dragging != null, child: child),
                  if (candidates.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: widget.spacing,
    runSpacing: widget.runSpacing,
    children: [
      for (var index = 0; index < widget.paths.length; index++)
        tile(context, index),
      ...widget.trailing,
    ],
  );
}
