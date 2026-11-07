import '../../ui/menu_popup.dart';
import '../../ui/menu_icon.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/record_conflicts.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../../ui/menu_field_label.dart';
import 'restaurant_address_fields.dart';
import 'restaurant_categories_page.dart';
import 'restaurant_category_input.dart';
import 'restaurant_record_draft.dart';
import 'restaurant_record_section.dart';
import 'restaurant_visit_editor.dart';
import 'visit_dish_editor.dart';
import '../photo_import/import_models.dart';

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
  late final category = TextEditingController(
    text: widget.restaurant?.category ?? '',
  );
  late final note = TextEditingController(text: widget.restaurant?.note ?? '');
  late final link = TextEditingController(text: widget.restaurant?.link ?? '');
  late List<RestaurantAddress> addresses =
      (widget.restaurant?.addressEntries ?? widget.initialAddresses)
          .map((entry) => RestaurantAddress.fromJson(entry.toJson()))
          .toList();
  late final recordDraft = RestaurantRecordDraft(
    widget.restaurant?.records ?? [],
  )..records.addAll(widget.initialRecords);
  late final draftId = widget.restaurant?.id ?? newId();
  late bool favorite = widget.restaurant?.favorite ?? false;
  late String _storedCategory = widget.restaurant?.category ?? '';
  bool saving = false;
  bool picking = false;
  bool get busy => saving || picking;
  bool leaving = false;
  bool get dirty =>
      recordDraft.dirty ||
      name.text != (widget.restaurant?.name ?? '') ||
      category.text != _storedCategory ||
      note.text != (widget.restaurant?.note ?? '') ||
      link.text != (widget.restaurant?.link ?? '') ||
      favorite != (widget.restaurant?.favorite ?? false) ||
      jsonEncode(addresses.map((a) => a.toJson()).toList()) !=
          jsonEncode(
            widget.restaurant?.addressEntries.map((a) => a.toJson()).toList() ??
                [],
          );
  @override
  void initState() {
    super.initState();
    for (final controller in [name, category, note, link]) {
      controller.addListener(changed);
    }
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    for (final controller in [name, category, note, link]) {
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

  Future<void> manageCategories() async {
    FocusScope.of(context).unfocus();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantCategoriesPage(
          onRenamed: (oldName, newName) {
            if (!mounted) return;
            if (_storedCategory == oldName) _storedCategory = newName;
            if (category.text == oldName) category.text = newName;
            changed();
          },
          onDeleted: (name) {
            if (!mounted) return;
            if (_storedCategory == name) _storedCategory = '';
            if (category.text == name) category.clear();
            changed();
          },
        ),
      ),
    );
  }

  Future<void> removeAddress(int index) async {
    final address = addresses[index];
    final records = recordDraft.records;
    if (records.any((r) => r.addressId == address.id)) {
      showToast(context, '已有用餐记录使用这个地址，请保留该分店');
      return;
    }
    if (!await confirmAction(
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
    setState(() => picking = true);
    await performAction(context, () async {
      final paths = await MenuScope.of(context).photos.pick();
      if (paths.isEmpty) return;
      final photos = <ImportPhoto>[];
      for (var offset = 0; offset < paths.length; offset += 8) {
        photos.addAll(
          await Future.wait(paths.skip(offset).take(8).map(readImportPhoto)),
        );
      }
      if (!mounted) return;
      final dates =
          photos.map((photo) => photo.date).whereType<DateTime>().toList()
            ..sort();
      final visit = Visit(
        id: newId(),
        date: dates.isEmpty ? DateTime.now() : dates.first,
        autoCost: true,
        addressId: addresses.length == 1 ? addresses.single.id : '',
        address: addresses.length == 1 ? addresses.single.fullAddress : '',
        items: photos
            .map(
              (photo) =>
                  VisitDish(dishId: '', name: '', imagePaths: [photo.path]),
            )
            .toList(),
      );
      setState(() => recordDraft.records.add(visit));
      if (dates.isEmpty) showToast(context, '照片没有拍摄时间，请核对消费日期');
    });
    if (mounted) setState(() => picking = false);
  }

  Future<void> editRecord([Visit? visit]) async {
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

  Future<void> editRecordDish(Visit visit, int index) async {
    final dish = await editVisitDish(context, visit.items[index]);
    if (dish == null || !mounted) return;
    setState(() {
      visit.items[index] = dish;
      visit.dishes = visit.items.map((item) => item.name).toList();
      if (visit.autoCost) {
        visit.totalCost = visit.bill.total;
      }
    });
  }

  Future<void> removeRecord(Visit visit) async {
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
    for (final visit in recordDraft.records) {
      if (!recordDraft.changed(visit)) continue;
      if (visit.address.isEmpty) {
        showToast(context, '请补充 ${dayLabel(visit.date)} 的消费分店');
        await editRecord(visit);
        return;
      }
      final missing = visit.items.indexWhere(
        (item) => item.name.trim().isEmpty,
      );
      if (missing >= 0) {
        showToast(
          context,
          '请补充 ${dayLabel(visit.date)} 第 ${missing + 1} 道菜的名称',
        );
        await editRecordDish(visit, missing);
        return;
      }
    }
    setState(() => saving = true);
    final store = MenuScope.of(context);
    final savedId = draftId;
    final success = await performAction(context, () async {
      final preparedRecords = await recordDraft.prepare(store);
      await store.update(MenuWriteScope.restaurant(savedId), (draft) {
        if (widget.restaurant != null) {
          requireUnchangedRecord(
            widget.restaurant!.toJson()..['category'] = _storedCategory,
            draft.restaurants
                .where((r) => r.id == widget.restaurant!.id)
                .firstOrNull
                ?.toJson(),
            ignored: {
              'records',
              'foods',
              if (favorite == widget.restaurant!.favorite) 'favorite',
            },
          );
        }
        final restaurant = widget.restaurant == null
            ? Restaurant(id: savedId, name: name.text.trim())
            : draft.restaurants.firstWhere(
                (r) => r.id == widget.restaurant!.id,
              );
        final records = recordDraft.merge(restaurant.records, preparedRecords);
        if (records.any(
          (v) =>
              v.addressId.isNotEmpty &&
              !addresses.any((a) => a.id == v.addressId),
        )) {
          throw StateError('已有用餐记录使用这个地址，请保留该分店');
        }
        restaurant.records = records;
        restaurant.name = name.text.trim();
        restaurant.category = category.text.trim();
        if (restaurant.category.isNotEmpty &&
            !draft.restaurantCategories.contains(restaurant.category)) {
          draft.restaurantCategories.add(restaurant.category);
        }
        restaurant.note = note.text.trim();
        restaurant.link = link.text.trim();
        if (widget.restaurant == null ||
            favorite != widget.restaurant!.favorite) {
          restaurant.favorite = favorite;
        }
        restaurant.addressEntries = addresses;
        restaurant.addresses = addresses.map((a) => a.fullAddress).toList();
        if (widget.restaurant == null) draft.restaurants.add(restaurant);
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
          title: Text(widget.restaurant == null ? '添加餐厅' : '编辑餐厅'),
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
                    child: Text(
                      saving ? '保存中…' : '保存餐厅',
                      style: const TextStyle(fontSize: 15),
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
                  MenuFieldLabel(
                    '菜系',
                    minHeight: 44,
                    bottomSpacing: 4,
                    trailing: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: manageCategories,
                      child: const Text('管理'),
                    ),
                  ),
                  RestaurantCategoryInput(
                    controller: category,
                    choices: restaurantCategoryNames(
                      MenuScope.of(context).data,
                    ),
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
                    records: recordDraft.records,
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
