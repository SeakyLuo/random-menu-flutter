import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Moves whole photo cards around the stack instead of paging their contents.
class RestaurantPhotoDeck extends StatefulWidget {
  const RestaurantPhotoDeck({
    super.key,
    required this.itemCount,
    required this.index,
    required this.itemBuilder,
    required this.onChanged,
    required this.onTap,
  });

  final int itemCount;
  final int index;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onChanged;
  final VoidCallback onTap;

  @override
  State<RestaurantPhotoDeck> createState() => _RestaurantPhotoDeckState();
}

class _RestaurantPhotoDeckState extends State<RestaurantPhotoDeck>
    with SingleTickerProviderStateMixin {
  static const _angle = 2 * math.pi / 180;
  static const _ratio = 1.65;
  late final AnimationController _motion = AnimationController(vsync: this)
    ..addListener(() {
      setState(() {
        _progress = lerpDouble(
          _from,
          _to,
          Curves.easeInOutCubic.transform(_motion.value),
        )!;
      });
    })
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (_to != 0) {
        widget.onChanged(
          (widget.index + (_to < 0 ? 1 : -1)) % widget.itemCount,
        );
      }
      setState(() => _progress = 0);
    });
  double _progress = 0;
  double _from = 0;
  double _to = 0;

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _settle(bool complete) {
    _from = _progress;
    _to = complete ? _progress.sign : 0;
    _motion.duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context)
          ? 0
          : complete
          ? 420
          : 240,
    );
    _motion.forward(from: 0);
  }

  void _release(DragEndDetails details) {
    if (_motion.isAnimating || _progress == 0) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    _settle(
      _progress.abs() >= .12 ||
          (velocity.abs() >= 600 && velocity.sign == _progress.sign),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final multiple = widget.itemCount > 1;
      final width = multiple
          ? constraints.maxWidth /
                (math.cos(_angle) + math.sin(_angle) / _ratio)
          : constraints.maxWidth;
      final height = width / _ratio;
      final vertical = multiple
          ? (width * math.sin(_angle) + height * (math.cos(_angle) - 1)) / 2
          : 0.0;
      final progress = _progress.abs();
      final forward = _progress <= 0;
      final other = (widget.index + (forward ? 1 : -1)) % widget.itemCount;
      final third = (widget.index + (forward ? 2 : 1)) % widget.itemCount;
      final hasThird = widget.itemCount > 2;
      // At the layer swap, both rotated bounding boxes must be disjoint.
      final halfAngle = _angle / 2;
      final separation =
          width * math.cos(halfAngle) + height * math.sin(halfAngle) + 8;
      final excursion = separation * math.sin(math.pi * progress);

      Widget face(int index, {required bool current, bool resting = false}) {
        final moving = !resting && (forward ? current : !current);
        final rotation = resting
            ? _angle
            : _angle * (current ? progress : 1 - progress);
        return Positioned.fill(
          key: ValueKey(index),
          child: Transform.translate(
            offset: Offset(moving ? excursion * _progress.sign : 0, 0),
            child: Transform.rotate(
              angle: rotation,
              child: RepaintBoundary(child: widget.itemBuilder(context, index)),
            ),
          ),
        );
      }

      final currentOnTop = progress < .5;
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: (constraints.maxWidth - width) / 2,
          vertical: vertical,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_motion.isAnimating && _progress == 0) widget.onTap();
          },
          onHorizontalDragUpdate: !multiple
              ? null
              : (details) {
                  if (_motion.isAnimating) return;
                  setState(() {
                    _progress = (_progress + details.delta.dx / (2 * width))
                        .clamp(-.5, .5);
                  });
                },
          onHorizontalDragEnd: multiple ? _release : null,
          onHorizontalDragCancel: !multiple
              ? null
              : () {
                  if (!_motion.isAnimating && _progress != 0) {
                    _settle(false);
                  }
                },
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // This covered card keeps the next backing photo continuous
                // when the outgoing card is tucked below the rest of the deck.
                if (hasThird && (currentOnTop || !forward))
                  face(third, current: false, resting: true),
                if (multiple && currentOnTop) face(other, current: false),
                face(widget.index, current: true),
                if (hasThird && !currentOnTop && forward)
                  face(third, current: false, resting: true),
                if (multiple && !currentOnTop) face(other, current: false),
              ],
            ),
          ),
        ),
      );
    },
  );
}
