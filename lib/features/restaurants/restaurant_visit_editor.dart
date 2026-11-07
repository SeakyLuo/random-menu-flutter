import '../../ui/menu_popup.dart';
import '../../ui/menu_bottom_sheet.dart';
import '../../ui/menu_icon.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/record_conflicts.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../../ui/library_widgets.dart';
import 'restaurant_address_editor.dart';
import 'restaurant_images.dart';
import 'visit_dish_editor.dart';
import 'restaurant_record_draft.dart';
import '../photo_import/import_models.dart';
import '../media/photo_widget.dart';

class RestaurantVisitEditor extends StatefulWidget {
  const RestaurantVisitEditor({
    super.key,
    required this.restaurant,
    this.visit,
    this.draftOnly = false,
  });
  final Restaurant restaurant;
  final Visit? visit;
  final bool draftOnly;
  @override
  State<RestaurantVisitEditor> createState() => _RestaurantVisitEditorState();
}

class _RestaurantVisitEditorState extends State<RestaurantVisitEditor> {
  late final initialDate = widget.visit?.date ?? DateTime.now();
  late DateTime date = initialDate;
  late final total = TextEditingController(
    text: widget.visit == null ? '0' : money(widget.visit!.totalCost),
  );
  late final companions = TextEditingController(
    text: widget.visit?.companions.join('，') ?? '',
  );
  late final note = TextEditingController(text: widget.visit?.note ?? '');
  late List<VisitDish> items =
      widget.visit?.items.map((i) => VisitDish.fromJson(i.toJson())).toList() ??
      [];
  late List<String> images = [...?widget.visit?.imagePaths];
  late bool autoCost = widget.visit?.autoCost ?? true;
  late String addressId =
      widget.visit?.addressId ??
      (widget.restaurant.addressEntries.length == 1
          ? widget.restaurant.addressEntries.single.id
          : '');
  late String address =
      widget.visit?.address ??
      (widget.restaurant.addressEntries.length == 1
          ? widget.restaurant.addressEntries.single.fullAddress
          : '');
  late final draftAddresses = widget.restaurant.addressEntries
      .map((entry) => RestaurantAddress.fromJson(entry.toJson()))
      .toList();
  List<RestaurantAddress> get availableAddresses => widget.draftOnly
      ? draftAddresses
      : MenuScope.of(context).data.restaurants
            .firstWhere((r) => r.id == widget.restaurant.id)
            .addressEntries;
  bool saving = false;
  bool picking = false;
  bool get busy => saving || picking;
  bool leaving = false;
  bool get dirty =>
      date != initialDate ||
      total.text !=
          (widget.visit == null ? '0' : money(widget.visit!.totalCost)) ||
      companions.text != (widget.visit?.companions.join('，') ?? '') ||
      note.text != (widget.visit?.note ?? '') ||
      autoCost != (widget.visit?.autoCost ?? true) ||
      addressId !=
          (widget.visit?.addressId ??
              (widget.restaurant.addressEntries.length == 1
                  ? widget.restaurant.addressEntries.single.id
                  : '')) ||
      address !=
          (widget.visit?.address ??
              (widget.restaurant.addressEntries.length == 1
                  ? widget.restaurant.addressEntries.single.fullAddress
                  : '')) ||
      jsonEncode(items.map((i) => i.toJson()).toList()) !=
          jsonEncode(
            widget.visit?.items.map((i) => i.toJson()).toList() ?? [],
          ) ||
      jsonEncode(images) != jsonEncode(widget.visit?.imagePaths ?? []) ||
      (widget.draftOnly &&
          jsonEncode(draftAddresses.map((a) => a.toJson()).toList()) !=
              jsonEncode(
                widget.restaurant.addressEntries
                    .map((a) => a.toJson())
                    .toList(),
              ));
  List<String> get people => companions.text
      .split(RegExp('[,，\n]'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.cost);
  @override
  void initState() {
    super.initState();
    for (final controller in [total, companions, note]) {
      controller.addListener(changed);
    }
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    total.dispose();
    companions.dispose();
    note.dispose();
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
    Navigator.pop(context);
  }

  Future<void> selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
    );
    if (time == null || !mounted) return;
    setState(
      () => date = DateTime(
        selected.year,
        selected.month,
        selected.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> addAddress() async {
    final store = MenuScope.of(context);
    final entry = await editRestaurantAddress(context);
    if (entry == null || !mounted) return;
    if (availableAddresses.any((a) => a.fullAddress == entry.fullAddress)) {
      showToast(context, '这个地址已经添加过了，请直接选择');
      return;
    }
    if (widget.draftOnly) {
      setState(() {
        draftAddresses.add(entry);
        addressId = entry.id;
        address = entry.fullAddress;
      });
      return;
    }
    final success = await performAction(
      context,
      () => store.update(MenuWriteScope.restaurant(widget.restaurant.id), (
        draft,
      ) {
        final r = draft.restaurants.firstWhere(
          (r) => r.id == widget.restaurant.id,
        );
        r.addressEntries.add(entry);
        r.addresses = r.addressEntries.map((a) => a.fullAddress).toList();
      }),
      success: '地址已添加',
    );
    if (success && mounted) {
      setState(() {
        addressId = entry.id;
        address = entry.fullAddress;
      });
    }
  }

  Future<void> chooseAddress() async {
    final entries = availableAddresses;
    if (entries.isEmpty) {
      await addAddress();
      return;
    }
    final selected = await showMenuBottomSheet<RestaurantAddress>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  '选择本次用餐分店',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in entries)
                      ListTile(
                        title: Text(entry.fullAddress),
                        trailing: entry.id == addressId
                            ? const MenuIcon(Icons.check)
                            : null,
                        onTap: () => Navigator.pop(context, entry),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        addressId = selected.id;
        address = selected.fullAddress;
      });
    }
  }

  void recalculate() {
    if (autoCost) total.text = money(subtotal);
  }

  Future<void> changeAutoCost(bool selected) async {
    if (selected &&
        double.tryParse(total.text) != subtotal &&
        !await confirmAction(
          context,
          title: '按菜品重新计算？',
          message: '消费总额将替换为菜品合计 ¥${money(subtotal)}。',
          confirmLabel: '使用菜品合计',
          destructive: false,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      autoCost = selected;
      recalculate();
    });
  }

  Future<void> addItem() async {
    final item = widget.draftOnly
        ? await editVisitDish(context, VisitDish(dishId: '', name: ''))
        : await pickVisitDish(context, widget.restaurant.id);
    if (item != null && mounted) {
      setState(() {
        items.add(item);
        recalculate();
      });
    }
  }

  Future<void> editItem(int index) async {
    final item = await editVisitDish(context, items[index]);
    if (item != null && mounted) {
      setState(() {
        items[index] = item;
        recalculate();
      });
    }
  }

  Future<void> addPhotoItems() async {
    setState(() => picking = true);
    await performAction(context, () async {
      final paths = await MenuScope.of(context).photos.pick();
      final photos = <ImportPhoto>[];
      for (var offset = 0; offset < paths.length; offset += 8) {
        photos.addAll(
          await Future.wait(paths.skip(offset).take(8).map(readImportPhoto)),
        );
      }
      if (!mounted) return;
      setState(() {
        if (items.isEmpty && widget.visit == null) {
          final dates = photos.map((p) => p.date).whereType<DateTime>().toList()
            ..sort();
          if (dates.isNotEmpty) date = dates.first;
        }
        items.addAll(
          photos.map(
            (photo) =>
                VisitDish(dishId: '', name: '', imagePaths: [photo.path]),
          ),
        );
        recalculate();
      });
    });
    if (mounted) setState(() => picking = false);
  }

  void moveItem(int from, int to) => setState(() {
    final item = items.removeAt(from);
    items.insert(to, item);
  });
  Future<void> removeItem(int index) async {
    if (!await confirmAction(
      context,
      title: '移除本次菜品？',
      message: '从本次点单中移除“${items[index].name}”，餐厅菜单会保留。',
      confirmLabel: '移除',
    )) {
      return;
    }
    if (mounted) {
      setState(() {
        items.removeAt(index);
        recalculate();
      });
    }
  }

  Future<void> save() async {
    if (address.isEmpty) {
      showToast(context, '请选择或添加本次用餐地址');
      return;
    }
    final value = total.text.trim().isEmpty
        ? 0.0
        : double.tryParse(total.text.trim());
    if (value == null || !value.isFinite || value < 0) {
      showToast(context, '请输入有效的消费总额');
      return;
    }
    if (people.toSet().length != people.length) {
      showToast(context, '饭搭子姓名重复，请检查');
      return;
    }
    if (widget.draftOnly) {
      final result = Visit(
        id: widget.visit?.id ?? newId(),
        date: date,
        totalCost: value,
        companions: people,
        note: note.text.trim(),
        items: items,
        dishes: items.map((item) => item.name).toList(),
        autoCost: autoCost,
        addressId: addressId,
        address: address,
        imagePaths: images,
      );
      setState(() => leaving = true);
      Navigator.pop(context, RestaurantVisitDraft(result, draftAddresses));
      return;
    }
    final store = MenuScope.of(context);
    setState(() => saving = true);
    final success = await performAction(context, () async {
      Future<String> keep(String path) async =>
          path.startsWith('${store.directory.path}/images/')
          ? path
          : await store.keepImage(path);
      final savedImages = await Future.wait(images.map(keep));
      final savedItems = await Future.wait(
        items.map(
          (i) async => VisitDish(
            dishId: i.dishId,
            name: i.name,
            price: i.price,
            quantity: i.quantity,
            note: i.note,
            imagePaths: await Future.wait(i.imagePaths.map(keep)),
          ),
        ),
      );
      await store.update(MenuWriteScope.restaurant(widget.restaurant.id), (
        draft,
      ) {
        final r = draft.restaurants.firstWhere(
          (r) => r.id == widget.restaurant.id,
        );
        if (widget.visit != null) {
          requireUnchangedRecord(
            widget.visit!.toJson(),
            r.records
                .where((v) => v.id == widget.visit!.id)
                .firstOrNull
                ?.toJson(),
          );
        }
        if (addressId.isNotEmpty &&
            !r.addressEntries.any((a) => a.id == addressId)) {
          throw StateError('餐厅地址已变化，请重新选择分店');
        }
        final edited = Visit(
          id: widget.visit?.id ?? newId(),
          date: date,
          totalCost: value,
          companions: people,
          note: note.text.trim(),
          dishes: savedItems.map((i) => i.name).toList(),
          items: savedItems,
          autoCost: autoCost,
          addressId: addressId,
          address: address,
          imagePaths: savedImages,
        );
        if (widget.visit == null) {
          r.records.add(edited);
        } else {
          r.records[r.records.indexWhere((v) => v.id == widget.visit!.id)] =
              edited;
        }
      });
    });
    if (!mounted) return;
    if (success) {
      showToast(context, '用餐记录已保存');
      setState(() => leaving = true);
      Navigator.pop(context);
    } else {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPeople =
        MenuScope.of(context).data.restaurants
            .expand((r) => r.records)
            .expand((r) => r.companions)
            .toSet()
            .toList()
          ..sort();
    final value = double.tryParse(total.text) ?? 0;
    return PopScope(
      canPop: leaving || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(widget.visit == null ? '记录一次用餐' : '编辑用餐记录'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: busy ? null : leave,
            icon: const MenuIcon(Icons.arrow_back),
          ),
        ),
        bottomNavigationBar: FixedPageActions(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : save,
                child: Text(
                  saving
                      ? '保存中…'
                      : widget.draftOnly
                      ? '完成'
                      : '保存记录',
                ),
              ),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('用餐时间'),
                subtitle: Text(
                  '${dayLabel(date)} ${TimeOfDay.fromDateTime(date).format(context)}',
                ),
                trailing: const MenuIcon(Icons.calendar_month_outlined),
                onTap: selectDate,
              ),
              SectionTitle(
                '用餐分店',
                trailing: TextButton.icon(
                  onPressed: addAddress,
                  icon: const MenuIcon(Icons.add, size: 18),
                  label: const Text('添加地址'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(address.isEmpty ? '选择本次用餐的分店' : address),
                trailing: const MenuIcon(Icons.chevron_right),
                onTap: chooseAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: companions,
                decoration: const InputDecoration(
                  labelText: '饭搭子',
                  hintText: '姓名用逗号分隔，独自用餐可留空',
                ),
              ),
              if (allPeople.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final person in allPeople)
                        FilterChip(
                          label: Text(person),
                          selected: people.contains(person),
                          onSelected: (selected) {
                            final list = people;
                            if (selected) {
                              list.add(person);
                            } else {
                              list.removeWhere((p) => p == person);
                            }
                            companions.text = list.join('，');
                          },
                        ),
                    ],
                  ),
                ),
              if (widget.draftOnly)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: addPhotoItems,
                    icon: const MenuIcon(
                      Icons.add_photo_alternate_outlined,
                      size: 18,
                    ),
                    label: const Text('批量添加照片'),
                  ),
                ),
              SectionTitle(
                '本次菜品 · ${items.length}',
                trailing: TextButton.icon(
                  onPressed: addItem,
                  icon: const MenuIcon(Icons.add, size: 18),
                  label: const Text('添加菜品'),
                ),
              ),
              if (items.isEmpty) const Text('可先记录饭搭子和环境，也可以添加本次吃过的菜。'),
              for (var i = 0; i < items.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: widget.draftOnly && items[i].imagePaths.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox.square(
                            dimension: 48,
                            child: LocalPhoto(path: items[i].imagePaths.first),
                          ),
                        )
                      : null,
                  title: Text(items[i].name.isEmpty ? '填写菜名' : items[i].name),
                  subtitle: Text(
                    '¥${money(items[i].price)} × ${items[i].quantity} 份 = ¥${money(items[i].cost)}',
                  ),
                  onTap: () => editItem(i),
                  trailing: MenuPopupButton<String>(
                    icon: const MenuIcon(Icons.more_horiz),
                    tooltip: '本次菜品操作',
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          editItem(i);
                        case 'up':
                          moveItem(i, i - 1);
                        case 'down':
                          moveItem(i, i + 1);
                        case 'remove':
                          removeItem(i);
                      }
                    },
                    itemBuilder: (_) => [
                      const MenuPopupItem(
                        icon: Icons.edit_outlined,
                        value: 'edit',
                        child: Text('编辑本次点单'),
                      ),
                      if (i > 0)
                        const MenuPopupItem(
                          icon: Icons.arrow_upward,
                          value: 'up',
                          child: Text('上移'),
                        ),
                      if (i < items.length - 1)
                        const MenuPopupItem(
                          icon: Icons.arrow_downward,
                          value: 'down',
                          child: Text('下移'),
                        ),
                      const MenuPopupItem(
                        icon: Icons.delete_outline,
                        destructive: true,
                        value: 'remove',
                        child: Text('移除'),
                      ),
                    ],
                  ),
                ),
              const SectionTitle('消费'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('按菜品自动计算'),
                subtitle: Text('菜品合计 ¥${money(subtotal)}'),
                value: autoCost,
                onChanged: changeAutoCost,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: total,
                readOnly: autoCost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '消费总额',
                  prefixText: '¥ ',
                  helperText: autoCost
                      ? '修改本次菜品的单价或数量可调整总额'
                      : '包含优惠、服务费等实际支付金额',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '共 ${people.length + 1} 人（含自己）${value > 0 && value.isFinite ? ' · 人均 ¥${money(value / (people.length + 1))}' : ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: note,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '用餐感受',
                  hintText: '记下这次用餐的小细节',
                ),
              ),
              const SectionTitle('环境照片'),
              RestaurantImages(
                paths: images,
                onBusyChanged: (value) => setState(() => picking = value),
                onChanged: (v) {
                  if (mounted) setState(() => images = v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
