import 'package:flutter/widgets.dart';

/// Let the mounted list covers paint before decoding the covered deck layers.
class RestaurantCoverBatch extends StatefulWidget {
  const RestaurantCoverBatch({super.key, required this.child});
  final Widget child;

  static RestaurantCoverBatchState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CoverBatchScope>()!.batch;

  @override
  State<RestaurantCoverBatch> createState() => RestaurantCoverBatchState();
}

class RestaurantCoverBatchState extends State<RestaurantCoverBatch> {
  final _pending = <Object>{};
  final _waiting = <Object, VoidCallback>{};
  bool _scheduled = false;

  Object begin(VoidCallback onReady) {
    final ticket = Object();
    _pending.add(ticket);
    _waiting[ticket] = onReady;
    return ticket;
  }

  void complete(Object ticket) {
    if (_pending.remove(ticket)) _releaseAfterFrame();
  }

  void remove(Object ticket) {
    _pending.remove(ticket);
    _waiting.remove(ticket);
    _releaseAfterFrame();
  }

  void _releaseAfterFrame() {
    if (_scheduled || _pending.isNotEmpty || _waiting.isEmpty) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _pending.isNotEmpty) return;
      final callbacks = _waiting.values.toList();
      _waiting.clear();
      for (final callback in callbacks) {
        callback();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _pending.clear();
    _waiting.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _CoverBatchScope(batch: this, child: widget.child);
}

class _CoverBatchScope extends InheritedWidget {
  const _CoverBatchScope({required this.batch, required super.child});
  final RestaurantCoverBatchState batch;

  @override
  bool updateShouldNotify(_CoverBatchScope oldWidget) =>
      batch != oldWidget.batch;
}
