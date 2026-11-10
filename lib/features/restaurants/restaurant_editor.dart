import '../../ui/menu_popup.dart';
import '../../ui/menu_icon.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../../ui/menu_field_label.dart';
import 'restaurant_address_fields.dart';
import 'restaurant_categories_page.dart';
import '../../ui/tag_selection_field.dart';
import 'restaurant_record_draft.dart';
import 'restaurant_record_section.dart';
import 'restaurant_entries.dart';
import 'visit_detail_page.dart';
import '../photo_import/photo_import_page.dart';
import 'restaurant_visit_editor.dart';
import 'visit_dish_editor.dart';
import 'restaurant_quick_create.dart';

Future<bool> editRestaurant(
  BuildContext context, {
  Restaurant? restaurant,
  List<RestaurantAddress> initialAddresses = const [],
  List<Visit> initialRecords = const [],
}) async =>
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => _RestaurantEditor(
          restaurant: restaurant,
          initialAddresses: initialAddresses,
          initialRecords: initialRecords,
        ),
      ),
    ) ==
    true;

class _RestaurantEditor extends StatefulWidget {
  const _RestaurantEditor({
    this.restaurant,
    required this.initialAddresses,
    required this.initialRecords,
  });
  final Restaurant? restaurant;
  final List<RestaurantAddress> initialAddresses;
  final List<Visit> initialRecords;
  @override
  State<_RestaurantEditor> createState() => _RestaurantEditorState();
}

class _RestaurantEditorState extends State<_RestaurantEditor> {
  late final name = TextEditingController(text: widget.restaurant?.name ?? '');
  late List<String> categories = [...?widget.restaurant?.categories];
  late final note = TextEditingController(text: widget.restaurant?.note ?? '');
  late final link = TextEditingController(text: widget.restaurant?.link ?? '');
  late List<RestaurantAddress> addresses =
      (widget.restaurant?.addressEntries ?? widget.initialAddresses)
          .map((entry) => RestaurantAddress.fromJson(entry.toJson()))
          .toList();
  late final recordDraft = RestaurantRecordDraft([])
    ..records.addAll(widget.initialRecords);
  late final _savedAddresses =
      widget.restaurant?.addressEntries
          .map((address) => RestaurantAddress.fromJson(address.toJson()))
          .toList() ??
      <RestaurantAddress>[];
  late final _detailsBefore = widget.restaurant?.toJson(includeRecords: false);
  bool get _addressesChanged =>
      jsonEncode(addresses.map((a) => a.toJson()).toList()) !=
      jsonEncode(_savedAddresses.map((a) => a.toJson()).toList());
  List<Visit> get _currentRecords => widget.restaurant == null
      ? recordDraft.records
      : MenuScope.of(
          context,
        ).data.restaurants.firstWhere((r) => r.id == draftId).records;

  Future<void> _openSavedRecord(
    Future<void> Function(Restaurant restaurant) open,
  ) async {
    final store = MenuScope.of(context);
    final beforeIds = store.data.restaurants
        .firstWhere((r) => r.id == draftId)
        .addressEntries
        .map((address) => address.id)
        .toSet();
    await open(store.data.restaurants.firstWhere((r) => r.id == draftId));
    if (!mounted) return;
    final added = store.data.restaurants
        .firstWhere((r) => r.id == draftId)
        .addressEntries
        .where((address) => !beforeIds.contains(address.id))
        .toList();
    setState(() {
      addresses.addAll(
        added.map((address) => RestaurantAddress.fromJson(address.toJson())),
      );
      _savedAddresses.addAll(
        added.map((address) => RestaurantAddress.fromJson(address.toJson())),
      );
      if (added.isNotEmpty) {
        final detailsBefore = _detailsBefore!;
        detailsBefore['addressEntries'] = _savedAddresses
            .map((address) => address.toJson())
            .toList();
        detailsBefore['addresses'] = _savedAddresses
            .map((address) => address.fullAddress)
            .toList();
      }
    });
  }

  late final draftId = widget.restaurant?.id ?? newId();
  late bool favorite = widget.restaurant?.favorite ?? false;
  late final List<String> _storedCategories = [
    ...?widget.restaurant?.categories,
  ];
  bool saving = false;
  bool picking = false;
  bool get busy => saving || picking;
  bool leaving = false;
  bool get dirty =>
      recordDraft.dirty ||
      name.text != (widget.restaurant?.name ?? '') ||
      jsonEncode(categories) != jsonEncode(_storedCategories) ||
      note.text != (widget.restaurant?.note ?? '') ||
      link.text != (widget.restaurant?.link ?? '') ||
      favorite != (widget.restaurant?.favorite ?? false) ||
      _addressesChanged;
  @override
  void initState() {
    super.initState();
    for (final controller in [name, note, link]) {
      controller.addListener(changed);
    }
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    for (final controller in [name, note, link]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> leave() async {
    if (busy) return;
    if (dirty &&
        !await confirmAction(
          context,
          title: '放弃此次编辑？',
          message: '还未保存的修改将丢失。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context, false);
  }

  String? _newAddressId;

  void addAddress() => setState(() {
    final address = RestaurantAddress(id: newId());
    addresses.add(address);
    _newAddressId = address.id;
  });

  Future<void> removeAddress(int index) async {
    final address = addresses[index];
    final linked = _currentRecords
        .where((r) => r.addressId == address.id)
        .toList();
    if (linked.isNotEmpty) {
      showToast(context, '此地址有 ${linked.length} 条消费记录，请先修改分店或删除相关记录');
      await editRecord(linked.first);
      return;
    }
    if (address.fullAddress.trim().isNotEmpty &&
        !await confirmAction(
          context,
          title: '移除地址？',
          message: address.fullAddress,
          confirmLabel: '移除',
        )) {
      return;
    }
    if (mounted) setState(() => addresses.removeAt(index));
  }

  Future<void> addRecordPhotos() async {
    if (widget.restaurant != null) {
      await _openSavedRecord(
        (restaurant) => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoImportPage(restaurantId: restaurant.id),
          ),
        ),
      );
      return;
    }

    setState(() => picking = true);
    await performAction(context, () async {
      final paths = await MenuScope.of(context).photos.pick(readLocation: true);
      if (paths.isEmpty) return;
      final draft = await buildRestaurantFromPhotos(paths);
      if (!mounted) return;
      setState(() {
        for (final address in draft.addresses) {
          final existing = addresses
              .where((entry) => entry.fullAddress == address.fullAddress)
              .firstOrNull;
          final target = existing ?? address;
          if (existing == null) addresses.add(address);
          for (final record in draft.records) {
            if (record.addressId == address.id) {
              record.addressId = target.id;
              record.address = target.fullAddress;
            }
          }
        }
        for (final record in draft.records) {
          if (record.addressId.isEmpty && addresses.length == 1) {
            record.addressId = addresses.single.id;
            record.address = addresses.single.fullAddress;
          }
        }
        recordDraft.records.addAll(draft.records);
      });
      if (draft.missingDates) {
        showToast(context, '部分照片没有拍摄时间，请核对消费日期');
      }
    });
    if (mounted) setState(() => picking = false);
  }

  Future<void> editRecord([Visit? visit]) async {
    if (widget.restaurant != null) {
      await _openSavedRecord(
        (restaurant) => editRestaurantVisit(context, restaurant, visit: visit),
      );
      return;
    }

    final snapshot = Restaurant(
      id: draftId,
      name: name.text.trim(),
      addressEntries: addresses
          .map((entry) => RestaurantAddress.fromJson(entry.toJson()))
          .toList(),
    );
    final result = await Navigator.push<RestaurantVisitDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantVisitEditor(
          restaurant: snapshot,
          visit: visit,
          draftOnly: true,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      addresses = result.addresses;
      if (visit == null) {
        recordDraft.records.add(result.visit);
      } else {
        recordDraft.records[recordDraft.records.indexWhere(
              (record) => record.id == visit.id,
            )] =
            result.visit;
      }
    });
  }

  Future<bool> _saveRecordDish(
    Visit before,
    int index,
    VisitDish dish,
    MenuCurrency currency,
  ) async {
    final changes = RestaurantRecordDraft([before]);
    final edited = changes.records.single;
    edited.items[index] = dish;
    edited.currency = currency;
    edited.dishes = edited.items.map((item) => item.name).toList();
    if (edited.autoCost) edited.totalCost = edited.bill.total;
    final store = MenuScope.of(context);
    return performAction(context, () async {
      final prepared = await changes.prepare(store);
      await store.update(MenuWriteScope.visit(draftId, before.id), (data) {
        final restaurant = data.restaurants.firstWhere((r) => r.id == draftId);
        restaurant.records = changes.merge(restaurant.records, prepared);
      });
    }, success: '消费记录已保存');
  }

  Future<void> editRecordDish(Visit visit, int index) async {
    final edited = Visit.fromJson(visit.toJson());
    final dish = await editVisitDish(
      context,
      edited.items[index],
      packages: edited.packages,
      currency: edited.currency,
      onCurrencyChanged: (value) => edited.currency = value,
      restaurantId: widget.restaurant?.id,
      onSave: widget.restaurant == null
          ? null
          : (dish, currency) => _saveRecordDish(visit, index, dish, currency),
    );
    if (dish == null || !mounted || widget.restaurant != null) return;
    edited.items[index] = dish;
    edited.dishes = edited.items.map((item) => item.name).toList();
    if (edited.autoCost) edited.totalCost = edited.bill.total;
    setState(
      () =>
          recordDraft.records[recordDraft.records.indexWhere(
                (record) => record.id == visit.id,
              )] =
              edited,
    );
  }

  Future<void> removeRecord(Visit visit) async {
    if (widget.restaurant != null) {
      await removeRestaurantVisit(context, draftId, visit);
      return;
    }

    if (!await confirmAction(
      context,
      title: '删除消费记录？',
      message: '${dayLabel(visit.date)} 的记录将在保存餐厅后删除。',
      confirmLabel: '删除',
    )) {
      return;
    }
    if (mounted) {
      setState(
        () =>
            recordDraft.records.removeWhere((record) => record.id == visit.id),
      );
    }
  }

  void moveAddress(int from, int to) => setState(() {
    final address = addresses.removeAt(from);
    addresses.insert(to, address);
  });
  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      showToast(context, '请填写餐厅名称');
      return;
    }
    if (!validateRestaurantAddresses(context, addresses)) return;
    final recordsChanged = recordDraft.dirty;
    if (recordsChanged) {
      for (final visit in recordDraft.records) {
        if (!recordDraft.changed(visit)) continue;
        if (visit.address.isEmpty) {
          showToast(context, '请补充 ${dayLabel(visit.date)} 的消费分店');
          await editRecord(visit);
          return;
        }
      }
    }
    setState(() => saving = true);
    final store = MenuScope.of(context);
    final savedId = draftId;
    final success = await performAction(context, () async {
      if (widget.restaurant != null) {
        await store.updateRestaurantDetails(
          before: {..._detailsBefore!, 'categories': _storedCategories},
          details: Restaurant(
            id: savedId,
            name: name.text.trim(),
            categories: [...categories],
            note: note.text.trim(),
            link: link.text.trim(),
            favorite: favorite,
            addressEntries: addresses,
          ),
          updateFavorite: favorite != widget.restaurant!.favorite,
        );
        return;
      }
      final preparedRecords = recordsChanged
          ? await recordDraft.prepare(store)
          : const <Visit>[];
      await store.update(MenuWriteScope.restaurant(savedId), (draft) {
        final restaurant = Restaurant(id: savedId, name: name.text.trim());
        final records = recordsChanged
            ? recordDraft.merge(restaurant.records, preparedRecords)
            : restaurant.records;
        if (records.any(
          (v) =>
              v.addressId.isNotEmpty &&
              !addresses.any((a) => a.id == v.addressId),
        )) {
          throw StateError('已有消费记录使用这个地址，请保留该分店');
        }
        restaurant.records = records;
        restaurant.name = name.text.trim();
        restaurant.categories = [...categories];
        draft.restaurantCategories = {
          ...draft.restaurantCategories,
          ...categories,
        }.toList();
        restaurant.note = note.text.trim();
        restaurant.link = link.text.trim();
        restaurant.favorite = favorite;
        restaurant.addressEntries = addresses;
        restaurant.addresses = addresses.map((a) => a.fullAddress).toList();
        draft.restaurants.add(restaurant);
      });
    });
    if (!mounted) return;
    if (success) {
      showToast(context, '餐厅已保存');
      setState(() => leaving = true);
      Navigator.pop(context, true);
    } else {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: leaving || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: MenuScrollTitle(
            child: Text(widget.restaurant == null ? '添加餐厅' : '编辑餐厅'),
          ),
          leading: IconButton(
            tooltip: '返回',
            onPressed: busy ? null : leave,
            icon: const MenuIcon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: favorite ? '取消收藏' : '收藏',
              isSelected: favorite,
              onPressed: busy
                  ? null
                  : () => setState(() => favorite = !favorite),
              icon: MenuIcon(
                favorite ? Icons.favorite : Icons.favorite_border,
                size: 23,
                color: favorite
                    ? const Color(0xffef4762)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : save,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (saving) ...[
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          saving ? '保存中…' : '保存餐厅',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: AbsorbPointer(
          absorbing: busy,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                primary: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  const MenuFieldLabel(
                    '餐厅名称',
                    isRequired: true,
                    minHeight: 44,
                    bottomSpacing: 4,
                  ),
                  TextField(
                    controller: name,
                    style: const TextStyle(fontSize: 15),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: '记下一家值得再去的店'),
                  ),
                  const SizedBox(height: 16),
                  TagSelectionField(
                    label: '菜系',
                    selected: categories,
                    hierarchical: true,
                    choices: restaurantCategoryNames(
                      MenuScope.of(context).data,
                    ),
                    busy: busy,
                    onChanged: (value) => setState(() => categories = value),
                  ),
                  const SizedBox(height: 16),
                  MenuFieldLabel(
                    '地址',
                    minHeight: 44,
                    bottomSpacing: 4,
                    icon: Icons.place_outlined,
                    trailing: IconButton(
                      tooltip: '添加地址',
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: addAddress,
                      icon: const MenuIcon(Icons.add, size: 20),
                    ),
                  ),
                  for (var i = 0; i < addresses.length; i++)
                    Padding(
                      key: ValueKey(addresses[i].id),
                      padding: EdgeInsets.only(
                        bottom: i == addresses.length - 1 ? 0 : 12,
                      ),
                      child: RestaurantAddressFields(
                        address: addresses[i],
                        autofocus: addresses[i].id == _newAddressId,
                        onChanged: (address) => setState(() {
                          addresses[i] = address;
                          for (final record in recordDraft.records) {
                            if (record.addressId == address.id) {
                              record.address = address.fullAddress;
                            }
                          }
                        }),
                        trailing: MenuPopupButton<String>(
                          icon: const MenuIcon(Icons.more_horiz),
                          tooltip: '地址操作',
                          onSelected: (value) {
                            switch (value) {
                              case 'up':
                                moveAddress(i, i - 1);
                              case 'down':
                                moveAddress(i, i + 1);
                              case 'delete':
                                removeAddress(i);
                            }
                          },
                          itemBuilder: (_) => [
                            if (i > 0)
                              const MenuPopupItem(
                                icon: Icons.arrow_upward,
                                value: 'up',
                                child: Text('上移'),
                              ),
                            if (i < addresses.length - 1)
                              const MenuPopupItem(
                                icon: Icons.arrow_downward,
                                value: 'down',
                                child: Text('下移'),
                              ),
                            const MenuPopupItem(
                              icon: Icons.delete_outline,
                              destructive: true,
                              value: 'delete',
                              child: Text('移除地址'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const MenuFieldLabel(
                    '评价',
                    icon: Icons.edit_note,
                    minHeight: 44,
                    bottomSpacing: 4,
                  ),
                  TextField(
                    controller: note,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: '口味、推荐理由或需要注意的事',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const MenuFieldLabel(
                    '相关链接',
                    icon: Icons.link,
                    minHeight: 44,
                    bottomSpacing: 4,
                  ),
                  TextField(
                    controller: link,
                    style: const TextStyle(fontSize: 15),
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(hintText: '店铺或地图链接'),
                  ),
                  const SizedBox(height: 16),
                  RestaurantRecordSection(
                    records: _currentRecords,
                    onAdd: () => editRecord(),
                    onPhotos: addRecordPhotos,
                    onEdit: editRecord,
                    onDish: editRecordDish,
                    onRemove: removeRecord,
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
