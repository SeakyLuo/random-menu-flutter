import '../../ui/menu_bottom_sheet.dart';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_tag_colors.dart';

enum _TagDestination { pool, preferred, excluded }

class RandomFilterSheet extends StatefulWidget {
  const RandomFilterSheet({
    super.key,
    required this.preferred,
    required this.excluded,
    required this.onRecipes,
    required this.header,
  });
  final Set<String> preferred;
  final Set<String> excluded;
  final VoidCallback onRecipes;
  final Widget header;
  @override
  State<RandomFilterSheet> createState() => _RandomFilterSheetState();
}

class _RandomFilterSheetState extends State<RandomFilterSheet> {
  late final Map<String, _TagDestination> _selection = {
    for (final tag in widget.preferred) tag: _TagDestination.preferred,
    for (final tag in widget.excluded) tag: _TagDestination.excluded,
  };

  void _move(String tag, _TagDestination destination) => setState(() {
    if (destination == _TagDestination.pool) {
      _selection.remove(tag);
    } else {
      _selection[tag] = destination;
    }
  });

  Color _color(_TagDestination? destination) => switch (destination) {
    _TagDestination.preferred => Theme.of(context).colorScheme.primary,
    _TagDestination.excluded => Theme.of(context).colorScheme.error,
    _TagDestination.pool ||
    null => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  Widget _tagFace(String tag, {bool removable = false}) {
    final tagColors = MenuTagColors.of(context);
    final color = tagColors.foreground;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: EdgeInsets.fromLTRB(13, 4, removable ? 4 : 13, 4),
      decoration: BoxDecoration(
        color: tagColors.background,
        border: Border.all(color: tagColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(tag, style: TextStyle(fontSize: 14, color: color)),
          ),
          if (removable)
            SizedBox.square(
              dimension: 24,
              child: IconButton(
                tooltip: '将$tag移回标签池',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _move(tag, _TagDestination.pool),
                icon: MenuIcon(Icons.close, size: 14, color: color),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tag(String tag) {
    final destination = _selection[tag];
    return LongPressDraggable<String>(
      data: tag,
      delay: const Duration(milliseconds: 250),
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: _tagFace(tag),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0,
        child: _tagFace(tag, removable: destination != null),
      ),
      child: Semantics(
        hint: '长按拖动，或点击选择区域',
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: PopupMenuButton<_TagDestination>(
            borderRadius: BorderRadius.circular(16),
            tooltip: '移动$tag',
            onSelected: (target) => _move(tag, target),
            itemBuilder: (_) => [
              if (destination != _TagDestination.preferred)
                const PopupMenuItem(
                  value: _TagDestination.preferred,
                  child: Text('想吃的'),
                ),
              if (destination != _TagDestination.excluded)
                const PopupMenuItem(
                  value: _TagDestination.excluded,
                  child: Text('这次不吃'),
                ),
              if (destination != null)
                const PopupMenuItem(
                  value: _TagDestination.pool,
                  child: Text('移回标签池'),
                ),
            ],
            child: _tagFace(tag, removable: destination != null),
          ),
        ),
      ),
    );
  }

  Widget _area(_TagDestination destination, List<String> tags) {
    final pool = destination == _TagDestination.pool;
    final color = _color(destination);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final title = switch (destination) {
      _TagDestination.pool => '标签池',
      _TagDestination.preferred => '想吃的',
      _TagDestination.excluded => '这次不吃',
    };
    return DragTarget<String>(
      onAcceptWithDetails: (details) => _move(details.data, destination),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return CustomPaint(
          foregroundPainter: pool && !hovering
              ? null
              : _DropBorderPainter(
                  color.withValues(alpha: hovering ? .65 : .32),
                  radius: 12,
                ),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            constraints: BoxConstraints(
              minHeight: pool ? 44 : 76,
              maxHeight: 132 * scale,
            ),
            padding: pool
                ? const EdgeInsets.symmetric(vertical: 4)
                : const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: hovering
                    ? .12
                    : pool
                    ? 0
                    : .055,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Semantics(
              container: true,
              label: title,
              child: tags.isEmpty
                  ? ConstrainedBox(
                      constraints: BoxConstraints(minHeight: pool ? 36 : 56),
                      child: Center(
                        heightFactor: 1,
                        child: Text(
                          pool ? '拖回这里取消选择' : title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: pool ? 12 : 14,
                            fontWeight: pool
                                ? FontWeight.w400
                                : FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final tag in tags) _tag(tag)],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = MenuScope.of(
      context,
    ).data.recipes.expand((recipe) => recipe.tags).toSet().toList()..sort();
    final pool = tags.where((tag) => !_selection.containsKey(tag)).toList();
    final preferred = tags
        .where((tag) => _selection[tag] == _TagDestination.preferred)
        .toList();
    final excluded = tags
        .where((tag) => _selection[tag] == _TagDestination.excluded)
        .toList();
    final largeText = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.8;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MenuSheetHandle(),
        widget.header,
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tags.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('还没有菜谱标签，添加后就能按口味挑选。'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onRecipes();
                      },
                      child: const Text('去整理菜谱'),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '长按拖动，也可点选',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _area(_TagDestination.pool, pool),
                  const SizedBox(height: 12),
                  if (largeText) ...[
                    _area(_TagDestination.preferred, preferred),
                    const SizedBox(height: 10),
                    _area(_TagDestination.excluded, excluded),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _area(_TagDestination.preferred, preferred),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _area(_TagDestination.excluded, excluded),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            spacing: 10,
            children: [
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  tooltip: '重置筛选',
                  onPressed: () => setState(_selection.clear),
                  icon: MenuIcon(
                    Icons.restart_alt,
                    size: 22,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, (
                    _selection.entries
                        .where(
                          (entry) => entry.value == _TagDestination.preferred,
                        )
                        .map((entry) => entry.key)
                        .toSet(),
                    _selection.entries
                        .where(
                          (entry) => entry.value == _TagDestination.excluded,
                        )
                        .map((entry) => entry.key)
                        .toSet(),
                  )),
                  child: const Text('应用筛选'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DropBorderPainter extends CustomPainter {
  const _DropBorderPainter(this.color, {required this.radius});
  final Color color;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(.5),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final edge in border.computeMetrics()) {
      for (double distance = 0; distance < edge.length; distance += 8) {
        canvas.drawPath(
          edge.extractPath(distance, min(distance + 4, edge.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DropBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
