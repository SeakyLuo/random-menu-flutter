import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../core/record_conflicts.dart';
import '../../ui/hero_sheet_route.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import 'restaurant_food_summary.dart';
import 'visit_dish_editor.dart';
import 'restaurant_dish_cover_menu.dart';

Future<void> showVisitDishDetail(
  BuildContext context, {
  required String restaurantId,
  required String visitId,
  required int itemIndex,
}) {
  final visit = MenuScope.of(context).data.restaurants
      .firstWhere((r) => r.id == restaurantId)
      .records
      .firstWhere((v) => v.id == visitId);
  return showHeroSheet<void>(
    context: context,
    constraints: BoxConstraints(
      maxWidth: 560,
      maxHeight: MediaQuery.sizeOf(context).height * .88,
    ),
    builder: (_) => _VisitDishSheet(
      restaurantId: restaurantId,
      visitId: visitId,
      itemIndex: itemIndex,
      item: VisitDish.fromJson(visit.items[itemIndex].toJson()),
      matchingItems: visit.items
          .where(
            (item) =>
                jsonEncode(item.toJson()) ==
                jsonEncode(visit.items[itemIndex].toJson()),
          )
          .length,
      package: visit.packageFor(visit.items[itemIndex]),
      currency: visit.currency,
    ),
  );
}

class _VisitDishSheet extends StatefulWidget {
  const _VisitDishSheet({
    required this.restaurantId,
    required this.visitId,
    required this.itemIndex,
    required this.item,
    required this.matchingItems,
    required this.package,
    required this.currency,
  });
  final String restaurantId;
  final String visitId;
  final int itemIndex;
  final VisitDish item;
  final int matchingItems;
  final VisitPackage? package;
  final MenuCurrency currency;

  @override
  State<_VisitDishSheet> createState() => _VisitDishSheetState();
}

class _VisitDishSheetState extends State<_VisitDishSheet> {
  late MenuCurrency _currency = widget.currency;
  late VisitDish _item = widget.item;
  late VisitPackage? _package = widget.package;
  late int _itemIndex = widget.itemIndex;
  late int _matchingItems = widget.matchingItems;
  bool _editing = false;
  final _photos = PageController();
  final _scroll = ScrollController();
  int _photo = 0;

  @override
  void dispose() {
    _photos.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int _locate(Visit visit) {
    final original = jsonEncode(_item.toJson());
    // Legacy dish IDs are not unique. Duplicate rows retain their ordinal;
    // a changed duplicate count cannot identify the original selection.
    final matches = [
      for (final (index, item) in visit.items.indexed)
        if (jsonEncode(item.toJson()) == original) index,
    ];
    if (matches.length != _matchingItems) return -1;
    if (matches.contains(_itemIndex)) return _itemIndex;
    return matches.length == 1 ? matches.single : -1;
  }

  Future<void> _edit() async {
    final store = MenuScope.of(context);
    setState(() => _editing = true);
    var saved = false;
    await performAction(context, () async {
      final visit = store.data.restaurants
          .firstWhere((r) => r.id == widget.restaurantId)
          .records
          .firstWhere((v) => v.id == widget.visitId);
      final index = _locate(visit);
      if (index < 0) {
        throw StateError('这条明细已被修改，请重新打开后编辑');
      }
      await editVisitDish(
        context,
        VisitDish.fromJson(_item.toJson()),
        packages: visit.packages,
        currency: visit.currency,
        restaurantId: widget.restaurantId,
        onSave: (edited, currency) => performAction(context, () async {
          edited.imagePaths = await Future.wait(
            edited.imagePaths.map(
              (path) => path.startsWith('${store.directory.path}/images/')
                  ? Future.value(path)
                  : store.keepImage(path),
            ),
          );
          var savedIndex = index;
          var matchingItems = _matchingItems;
          await store.update(
            MenuWriteScope.visit(widget.restaurantId, widget.visitId),
            (draft) {
              final current = draft.restaurants
                  .firstWhere((r) => r.id == widget.restaurantId)
                  .records
                  .firstWhere((v) => v.id == widget.visitId);
              savedIndex = _locate(current);
              requireUnchangedRecord(
                _item.toJson(),
                savedIndex < 0 ? null : current.items[savedIndex].toJson(),
              );
              for (final packageId in {
                _item.packageId,
                edited.packageId,
              }.nonNulls) {
                final before = visit.packages.firstWhere(
                  (p) => p.id == packageId,
                );
                final latest = current.packages
                    .where((p) => p.id == packageId)
                    .firstOrNull;
                requireUnchangedRecord(before.toJson(), latest?.toJson());
              }
              requireUnchangedRecord(
                {'currency': visit.currency.code},
                {'currency': current.currency.code},
              );
              current.currency = currency;
              current.items[savedIndex] = edited;
              matchingItems = current.items
                  .where(
                    (item) =>
                        jsonEncode(item.toJson()) ==
                        jsonEncode(edited.toJson()),
                  )
                  .length;
              if (current.autoCost) current.totalCost = current.bill.total;
            },
          );
          saved = true;
          if (!mounted) return;
          setState(() {
            _item = edited;
            _currency = currency;
            _itemIndex = savedIndex;
            _matchingItems = matchingItems;
            _package = edited.packageId == null
                ? null
                : visit.packages.firstWhere((p) => p.id == edited.packageId);
            _photo = 0;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _photos.hasClients) _photos.jumpToPage(0);
          });
        }),
      );
    });
    if (!mounted) return;
    setState(() => _editing = false);
    if (saved) showToast(context, '明细已保存');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final paths = _item.imagePaths;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: MenuScrollTitle(
                      controller: _scroll,
                      child: const Text(
                        '菜品详情',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '编辑明细',
                    onPressed: _editing ? null : _edit,
                    icon: const MenuIcon(Icons.edit_outlined, size: 23),
                  ),
                  RestaurantDishCoverMenu(
                    restaurantId: widget.restaurantId,
                    dishId: _item.dishId,
                    enabled: !_editing,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                controller: _scroll,
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: LayoutBuilder(
                      builder: (context, constraints) => SizedBox(
                        height: math.min(320, constraints.maxWidth / 1.25),
                        child: paths.isEmpty
                            ? ColoredBox(
                                color: colors.surfaceContainer,
                                child: Center(
                                  child: MenuIcon(
                                    Icons.ramen_dining_outlined,
                                    size: 42,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : PageView.builder(
                                controller: _photos,
                                itemCount: paths.length,
                                onPageChanged: (index) =>
                                    setState(() => _photo = index),
                                itemBuilder: (_, index) => GestureDetector(
                                  onTap: () => showPhotoViewer(
                                    context,
                                    paths,
                                    index,
                                    title: _item.name,
                                    heroTagForIndex: (i) => (this, i),
                                    onReturnIndex: (next) {
                                      if (!mounted) return;
                                      setState(() => _photo = next);
                                      _photos.jumpToPage(next);
                                    },
                                  ),
                                  child: Hero(
                                    tag: (this, index),
                                    child: LocalPhoto(path: paths[index]),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (paths.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${_photo + 1} / ${paths.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onLongPress: _item.name.isEmpty
                        ? null
                        : () => performAction(
                            context,
                            () => Clipboard.setData(
                              ClipboardData(text: _item.name),
                            ),
                            success: '名称已复制',
                          ),
                    child: Text(
                      _item.name.isEmpty ? '未命名菜品' : _item.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _package == null
                        ? '${_currency.symbol}${money(_item.price)} · ${_item.quantity} 份'
                        : '${visitPackageLabel(_package!, currency: _currency)} · ${_item.quantity} 份',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (_item.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SelectableText(
                        '“${_item.note}”',
                        style: const TextStyle(fontSize: 14, height: 1.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
