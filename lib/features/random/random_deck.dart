import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import 'random_recipe_card.dart';

enum PickAction { add, skip, reset }

class RandomDeck extends StatefulWidget {
  const RandomDeck({
    super.key,
    required this.recipes,
    required this.enabled,
    required this.target,
    required this.onAction,
    required this.onBusy,
    required this.onProgress,
    required this.onOpen,
    required this.onFavorite,
  });
  final List<Recipe> recipes;
  final bool enabled;
  final GlobalKey target;
  final Future<bool> Function(PickAction, Future<void>) onAction;
  final ValueChanged<bool> onBusy;
  final ValueChanged<double> onProgress;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  @override
  State<RandomDeck> createState() => RandomDeckState();
}

class RandomDeckState extends State<RandomDeck>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(vsync: this)
    ..addListener(() {
      if (_action == PickAction.add) widget.onProgress(_curve);
      if (_recoveringAdd) widget.onProgress(1 - _curve);
    });
  final _stage = GlobalKey();
  Offset _drag = Offset.zero;
  Axis? _axis;
  Offset _from = Offset.zero;
  Offset _destination = Offset.zero;
  double _targetScale = 1;
  double _height = 1;
  bool _busy = false;
  bool get _locked => _busy || !widget.enabled;
  bool _settling = false;
  bool _entering = false;
  bool _recoveringAdd = false;
  double _returnProgress = 0;
  PickAction? _action;
  double get _curve => const Cubic(.22, .8, .25, 1).transform(_motion.value);
  double get _dragProgress =>
      ((_axis == Axis.horizontal ? _drag.dx.abs() : _drag.dy.abs()) /
              (_height * .6))
          .clamp(0, 1);

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> choose(
    PickAction action, {
    Offset direction = const Offset(0, 1),
  }) async {
    if (_locked) return;
    setState(() {
      _busy = true;
      _action = action;
      _from = _drag;
    });
    widget.onBusy(true);
    final box = _stage.currentContext!.findRenderObject()! as RenderBox;
    final distance = MediaQuery.sizeOf(context).longestSide + _height;
    _destination = direction * distance;
    _targetScale = 1;
    if (action == PickAction.add) {
      final target =
          widget.target.currentContext!.findRenderObject()! as RenderBox;
      _destination =
          target.localToGlobal(target.size.center(Offset.zero)) -
          box.localToGlobal(box.size.center(Offset.zero));
      _targetScale = target.size.width / box.size.width;
    } else if (action == PickAction.reset) {
      _destination = Offset(distance, 0);
    }
    _motion.duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context)
          ? 0
          : action == PickAction.add
          ? 380
          : 300,
    );
    final animated = _motion.forward(from: 0).orCancel;
    final saved = await widget.onAction(action, animated);
    if (!mounted) return;
    if (!saved || action == PickAction.reset) {
      setState(() {
        _recoveringAdd = !saved && action == PickAction.add;
        _returnProgress = saved ? 0 : 1;
        _action = null;
        _settling = true;
        _entering = saved;
        _from = saved
            ? const Offset(0, 18)
            : Offset.lerp(_from, _destination, _curve)!;
      });
      _motion.duration = Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 300,
      );
      await _motion.forward(from: 0).orCancel;
      if (!mounted) return;
    }
    setState(() {
      _action = null;
      _settling = false;
      _entering = false;
      _recoveringAdd = false;
      _drag = Offset.zero;
      _busy = false;
      _motion.reset();
    });
    widget.onProgress(0);
    widget.onBusy(false);
  }

  Future<void> _return() async {
    setState(() {
      _returnProgress = _dragProgress;
      _settling = true;
      _busy = true;
      _from = _drag;
    });
    widget.onBusy(true);
    _motion.duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 340,
    );
    await _motion.forward(from: 0).orCancel;
    if (!mounted) return;
    setState(() {
      _settling = false;
      _busy = false;
      _drag = Offset.zero;
      _motion.reset();
    });
    widget.onBusy(false);
  }

  void _release(DragEndDetails details) {
    final threshold = math.min(100, _height * .18);
    if ((_axis == Axis.horizontal ? _drag.dx.abs() : _drag.dy.abs()) <
        threshold) {
      _return();
      return;
    }
    if (_axis == Axis.vertical) {
      choose(_drag.dy < 0 ? PickAction.add : PickAction.skip);
    } else {
      choose(PickAction.skip, direction: Offset(_drag.dx.sign, 0));
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.min(
        400.0,
        math.min(
          MediaQuery.sizeOf(context).height * .48,
          math.min(
            constraints.maxHeight - 120,
            (constraints.maxWidth - 32) * 1.25,
          ),
        ),
      );
      _height = height;
      return Column(
        children: [
          const Spacer(),
          SizedBox(
            key: _stage,
            height: height,
            width: height * .8,
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, _) {
                final progress = _settling
                    ? _returnProgress * (1 - _curve)
                    : _action == PickAction.reset
                    ? 0.0
                    : _action == null
                    ? _dragProgress
                    : _curve;
                final front = _settling
                    ? Offset.lerp(_from, Offset.zero, _curve)!
                    : _action != null
                    ? Offset.lerp(_from, _destination, _curve)!
                    : _drag;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (
                      var depth = widget.recipes.length - 1;
                      depth >= 0;
                      depth--
                    )
                      Positioned.fill(
                        key: ValueKey(widget.recipes[depth].id),
                        child: Offstage(
                          // The fourth card loads while hidden and keeps its
                          // image stream when it advances into the visible deck.
                          offstage: depth >= 3,
                          child: Transform.translate(
                            offset: depth == 0
                                ? front
                                : Offset.lerp(
                                    depth == 1
                                        ? const Offset(10, 9)
                                        : const Offset(-11, 10),
                                    depth == 1
                                        ? Offset.zero
                                        : const Offset(10, 9),
                                    progress,
                                  )!,
                            child: Transform.rotate(
                              angle: depth == 0
                                  ? (_action == PickAction.add || _settling
                                                ? _from.dx / 45 * (1 - _curve)
                                                : front.dx / 45)
                                            .clamp(-12, 12) *
                                        math.pi /
                                        180
                                  : lerpDouble(
                                          depth == 1 ? 3 : -4,
                                          depth == 1 ? 0 : 3,
                                          progress,
                                        )! *
                                        math.pi /
                                        180,
                              child: Transform.scale(
                                scale: depth == 0
                                    ? _action == PickAction.add
                                          ? lerpDouble(1, _targetScale, _curve)!
                                          : _recoveringAdd
                                          ? lerpDouble(_targetScale, 1, _curve)!
                                          : _settling && _entering
                                          ? lerpDouble(.97, 1, _curve)!
                                          : 1
                                    : lerpDouble(
                                        depth == 1 ? .97 : .96,
                                        depth == 1 ? 1 : .97,
                                        progress,
                                      )!,
                                child: Opacity(
                                  opacity: depth == 0
                                      ? _settling
                                            ? _entering
                                                  ? _curve
                                                  : 1
                                            : _action == PickAction.skip ||
                                                  _action == PickAction.reset
                                            ? 1 - _curve
                                            : 1
                                      : 1,
                                  child: GestureDetector(
                                    onPanStart: _locked
                                        ? null
                                        : (_) {
                                            _axis = null;
                                            _motion.reset();
                                          },
                                    onPanUpdate: _locked || depth > 0
                                        ? null
                                        : (d) => setState(() {
                                            _drag += d.delta;
                                            if (_axis == null &&
                                                math.max(
                                                      _drag.dx.abs(),
                                                      _drag.dy.abs(),
                                                    ) >
                                                    10) {
                                              _axis =
                                                  _drag.dx.abs() >
                                                      _drag.dy.abs()
                                                  ? Axis.horizontal
                                                  : Axis.vertical;
                                            }
                                          }),
                                    onPanEnd: _locked || depth > 0
                                        ? null
                                        : _release,
                                    onPanCancel: _locked || depth > 0
                                        ? null
                                        : _return,
                                    child: RepaintBoundary(
                                      child: RandomRecipeCard(
                                        recipe: widget.recipes[depth],
                                        captionOpacity:
                                            depth == 0 && _recoveringAdd
                                            ? _curve
                                            : depth == 0 &&
                                                  _action == PickAction.add
                                            ? 1 - _curve
                                            : 1,
                                        onOpen: depth == 0 && !_locked
                                            ? widget.onOpen
                                            : null,
                                        onFavorite: depth == 0 && !_locked
                                            ? widget.onFavorite
                                            : null,
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
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _choice('跳过', Icons.close, false, () => choose(PickAction.skip)),
              const SizedBox(width: 44),
              _choice('加入菜单', Icons.check, true, () => choose(PickAction.add)),
            ],
          ),
          const Spacer(),
        ],
      );
    },
  );

  Widget _choice(
    String label,
    IconData icon,
    bool primary,
    VoidCallback action,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: primary ? scheme.primary : scheme.surface,
              foregroundColor: primary ? scheme.onPrimary : scheme.onSurface,
              disabledBackgroundColor: primary
                  ? scheme.primary
                  : scheme.surface,
              disabledForegroundColor: primary
                  ? scheme.onPrimary
                  : scheme.onSurface,
              side: BorderSide(
                color: primary ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            tooltip: label,
            onPressed: _locked ? null : action,
            icon: MenuIcon(icon, size: primary ? 36 : 30),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
