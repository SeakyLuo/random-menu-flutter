import '../../ui/menu_bottom_sheet.dart';
import '../../ui/menu_currency_picker.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_field_label.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/record_conflicts.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../../ui/library_widgets.dart';
import 'restaurant_address_editor.dart';
import 'restaurant_companion_field.dart';
import 'restaurant_images.dart';
import 'visit_dish_editor.dart';
import 'visit_coupon_fields.dart';
import 'visit_package_fields.dart';
import 'visit_food_groups.dart';
import '../../ui/menu_popup.dart';
import 'restaurant_record_draft.dart';
import '../photo_import/import_models.dart';

part 'restaurant_visit_editor_form.dart';
part 'restaurant_visit_editor_foods.dart';

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
  late final Visit? _savedVisit = widget.visit == null
      ? null
      : Visit.fromJson(widget.visit!.toJson());
  bool get _independentFoods => widget.visit != null && !widget.draftOnly;
  late List<VisitDish> items =
      widget.visit?.items.map((i) => VisitDish.fromJson(i.toJson())).toList() ??
      [];
  late List<String> images = [...?widget.visit?.imagePaths];
  late List<VisitCoupon> coupons = [...?widget.visit?.coupons];
  late List<VisitPackage> packages = [...?widget.visit?.packages];
  late MenuCurrency currency = widget.visit?.currency ?? MenuCurrency.cny;
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
  bool foodSaving = false;
  bool get busy => saving || picking || foodSaving;
  bool leaving = false;
  VoidCallback? dismissDishUndo;
  late final _initialFoodsJson = jsonEncode({
    'items': _savedVisit?.items.map((item) => item.toJson()).toList() ?? [],
    'packages':
        _savedVisit?.packages.map((package) => package.toJson()).toList() ?? [],
  });
  bool get dirty =>
      currency != (_savedVisit?.currency ?? MenuCurrency.cny) ||
      date != initialDate ||
      total.text !=
          (_savedVisit == null ? '0' : money(_savedVisit.totalCost)) ||
      companions.text != (_savedVisit?.companions.join('，') ?? '') ||
      note.text != (_savedVisit?.note ?? '') ||
      autoCost != (_savedVisit?.autoCost ?? true) ||
      jsonEncode(coupons.map((c) => c.toJson()).toList()) !=
          jsonEncode(
            _savedVisit?.coupons.map((c) => c.toJson()).toList() ?? [],
          ) ||
      addressId !=
          (_savedVisit?.addressId ??
              (widget.restaurant.addressEntries.length == 1
                  ? widget.restaurant.addressEntries.single.id
                  : '')) ||
      address !=
          (_savedVisit?.address ??
              (widget.restaurant.addressEntries.length == 1
                  ? widget.restaurant.addressEntries.single.fullAddress
                  : '')) ||
      (!_independentFoods &&
          jsonEncode({
                'items': items.map((item) => item.toJson()).toList(),
                'packages': packages
                    .map((package) => package.toJson())
                    .toList(),
              }) !=
              _initialFoodsJson) ||
      jsonEncode(images) != jsonEncode(_savedVisit?.imagePaths ?? []) ||
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
  double get subtotal => visitSubtotal(items, packages);
  VisitBill get bill => VisitBill(subtotal, coupons);
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
    dismissDishUndo?.call();
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
    dismissDishUndo?.call();
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
    if (autoCost) total.text = money(bill.total);
  }

  Future<void> changeAutoCost(bool selected) async {
    if (selected &&
        double.tryParse(total.text) != bill.total &&
        !await confirmAction(
          context,
          title: '按菜品重新计算？',
          message:
              '菜品合计 ${currency.symbol}${money(bill.subtotal)}，用券抵扣 ${currency.symbol}${money(bill.discount)}，实付将改为 ${currency.symbol}${money(bill.total)}。',
          confirmLabel: '使用自动计算',
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

  Future<void> save() async {
    if (_independentFoods && !dirty) {
      dismissDishUndo?.call();
      setState(() => leaving = true);
      Navigator.pop(context);
      return;
    }

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
      dismissDishUndo?.call();
      final result = Visit(
        id: widget.visit?.id ?? newId(),
        date: date,
        totalCost: value,
        currency: currency,
        companions: people,
        note: note.text.trim(),
        items: items,
        coupons: coupons,
        packages: packages,
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
    dismissDishUndo?.call();
    setState(() => saving = true);
    final success = await performAction(context, () async {
      Future<String> keep(String path) async =>
          path.startsWith('${store.directory.path}/images/')
          ? path
          : await store.keepImage(path);
      final savedImages = await Future.wait(images.map(keep));
      final savedItems = _independentFoods
          ? items
          : await Future.wait(
              items.map(
                (i) async => VisitDish(
                  dishId: i.dishId,
                  isDish: i.isDish,
                  packageId: i.packageId,
                  name: i.name,
                  price: i.price,
                  quantity: i.quantity,
                  note: i.note,
                  imagePaths: await Future.wait(i.imagePaths.map(keep)),
                ),
              ),
            );
      await store.update(
        widget.visit == null
            ? MenuWriteScope.restaurant(widget.restaurant.id)
            : MenuWriteScope.visit(widget.restaurant.id, widget.visit!.id),
        (draft) {
          final r = draft.restaurants.firstWhere(
            (r) => r.id == widget.restaurant.id,
          );
          final current = widget.visit == null
              ? null
              : r.records
                    .where((visit) => visit.id == widget.visit!.id)
                    .firstOrNull;
          if (widget.visit != null) {
            requireUnchangedRecord(
              _visitMetadata(_savedVisit!),
              current == null ? null : _visitMetadata(current),
            );
          }
          final actualItems = _independentFoods ? current!.items : savedItems;
          final actualPackages = _independentFoods
              ? current!.packages
              : packages;
          if (addressId.isNotEmpty &&
              !r.addressEntries.any((a) => a.id == addressId)) {
            throw StateError('餐厅地址已变化，请重新选择分店');
          }
          final edited = Visit(
            id: widget.visit?.id ?? newId(),
            date: date,
            totalCost: autoCost
                ? VisitBill(
                    visitSubtotal(actualItems, actualPackages),
                    coupons,
                  ).total
                : value,
            currency: currency,
            companions: people,
            note: note.text.trim(),
            dishes: actualItems.map((i) => i.name).toList(),
            items: actualItems,
            coupons: coupons,
            packages: actualPackages,
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
        },
      );
    });
    if (!mounted) return;
    if (success) {
      showToast(context, '消费记录已保存');
      setState(() => leaving = true);
      Navigator.pop(context);
    } else {
      setState(() => saving = false);
    }
  }

  void updateForm(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => _buildEditor(context);
}
