import '../../ui/menu_icon.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../../ui/menu_field_label.dart';
import '../../ui/menu_numeric_fields.dart';
import '../../ui/menu_popup.dart';
import 'restaurant_images.dart';
import 'restaurant_food_summary.dart';
import 'restaurant_dish_cover_menu.dart';

Future<VisitDish?> editVisitDish(
  BuildContext context,
  VisitDish item, {
  bool requirePrice = false,
  MenuCurrency currency = MenuCurrency.cny,
  ValueChanged<MenuCurrency>? onCurrencyChanged,
  List<VisitPackage> packages = const [],
  String? restaurantId,
  Future<bool> Function(VisitDish item, MenuCurrency currency)? onSave,
}) => Navigator.push<VisitDish>(
  context,
  MaterialPageRoute(
    builder: (_) => _VisitDishEditor(
      item: item,
      currency: currency,
      onCurrencyChanged: onCurrencyChanged,
      requirePrice: requirePrice,
      packages: packages,
      restaurantId: restaurantId,
      onSave: onSave,
    ),
  ),
);

class _VisitDishEditor extends StatefulWidget {
  const _VisitDishEditor({
    required this.item,
    required this.currency,
    this.onCurrencyChanged,
    this.requirePrice = false,
    required this.packages,
    required this.restaurantId,
    this.onSave,
  });
  final bool requirePrice;
  final List<VisitPackage> packages;
  final VisitDish item;
  final MenuCurrency currency;
  final ValueChanged<MenuCurrency>? onCurrencyChanged;
  final String? restaurantId;
  final Future<bool> Function(VisitDish item, MenuCurrency currency)? onSave;
  @override
  State<_VisitDishEditor> createState() => _VisitDishEditorState();
}

class _VisitDishEditorState extends State<_VisitDishEditor> {
  late MenuCurrency currency = widget.currency;
  late final name = TextEditingController(text: widget.item.name);
  late final price = TextEditingController(
    text: widget.requirePrice ? '' : money(widget.item.price),
  );
  late final quantity = TextEditingController(text: '${widget.item.quantity}');
  late final note = TextEditingController(text: widget.item.note);
  late List<String> images = [...widget.item.imagePaths];
  late String? packageId = widget.item.packageId;
  late bool isDish = widget.item.isDish;
  bool leaving = false;
  bool picking = false;
  bool saving = false;
  bool get busy => picking || saving;
  bool get dirty =>
      currency != widget.currency ||
      isDish != widget.item.isDish ||
      name.text != widget.item.name ||
      price.text != (widget.requirePrice ? '' : money(widget.item.price)) ||
      quantity.text != '${widget.item.quantity}' ||
      note.text != widget.item.note ||
      packageId != widget.item.packageId ||
      jsonEncode(images) != jsonEncode(widget.item.imagePaths);
  @override
  void initState() {
    super.initState();
    for (final c in [name, price, quantity, note]) {
      c.addListener(changed);
    }
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    for (final c in [name, price, quantity, note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> leave() async {
    if (busy) return;
    if (dirty &&
        !await confirmAction(
          context,
          title: '放弃菜品修改？',
          message: '本次点单的修改还未完成。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context);
  }

  Future<void> save() async {
    final cost = packageId == null
        ? double.tryParse(price.text.trim())
        : widget.item.price;
    final count = int.tryParse(quantity.text.trim());
    if (cost == null || !cost.isFinite || cost < 0) {
      showToast(context, '请输入有效的单价');
      return;
    }
    if (count == null || count < 1 || count > 100) {
      showToast(context, '数量应为 1 到 100 份');
      return;
    }
    final item = VisitDish(
      dishId: widget.item.dishId,
      isDish: isDish,
      packageId: packageId,
      name: name.text.trim(),
      price: cost,
      quantity: count,
      note: note.text.trim(),
      imagePaths: images,
    );
    if (widget.onSave != null) {
      FocusScope.of(context).unfocus();
      setState(() => saving = true);
      final success = await widget.onSave!(item, currency);
      if (!mounted) return;
      if (!success) {
        setState(() => saving = false);
        return;
      }
    }
    if (!mounted) return;
    widget.onCurrencyChanged?.call(currency);
    setState(() => leaving = true);
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(price.text) ?? 0;
    final count = int.tryParse(quantity.text) ?? 0;
    return PopScope(
      canPop: leaving || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: MenuScrollTitle(child: const Text('本次点单')),
          actions: [
            RestaurantDishCoverMenu(
              restaurantId: widget.restaurantId,
              dishId: widget.item.dishId,
              enabled: !busy,
            ),
          ],
          leading: IconButton(
            tooltip: '返回',
            onPressed: busy ? null : leave,
            icon: const MenuIcon(Icons.arrow_back),
          ),
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
                      children: [
                        if (saving) ...[
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          saving
                              ? '保存中…'
                              : widget.onSave == null
                              ? '完成'
                              : '保存菜品',
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
                  MenuFieldLabel(
                    '名称',
                    minHeight: 44,
                    bottomSpacing: 4,
                    trailing: MergeSemantics(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => isDish = !isDish),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: isDish,
                                onChanged: (value) =>
                                    setState(() => isDish = value!),
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              const Text('菜品', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: name,
                    style: const TextStyle(fontSize: 15),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: '可不填，之后再补充'),
                  ),
                  const SizedBox(height: 24),
                  RestaurantImages(
                    paths: images,
                    cover: true,
                    editorStyle: true,
                    onBusyChanged: (value) => setState(() => picking = value),
                    onChanged: (value) {
                      if (mounted) setState(() => images = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  if (widget.packages.isNotEmpty) ...[
                    const MenuFieldLabel('计价方式'),
                    MenuPopupButton<String>(
                      tooltip: '选择计价方式',
                      matchAnchorWidth: true,
                      borderRadius: BorderRadius.circular(12),
                      itemBuilder: (_) => [
                        MenuPopupItem(
                          value: '',
                          icon: Icons.restaurant,
                          selected: packageId == null,
                          child: const Text('单点'),
                        ),
                        for (final package in widget.packages)
                          MenuPopupItem(
                            value: package.id,
                            icon: Icons.receipt_long_outlined,
                            selected: packageId == package.id,
                            child: Text(
                              visitPackageLabel(package, currency: currency),
                            ),
                          ),
                      ],
                      onSelected: (value) => setState(
                        () => packageId = value == '' ? null : value,
                      ),
                      child: InputDecorator(
                        decoration: const InputDecoration(),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                packageId == null
                                    ? '单点'
                                    : visitPackageLabel(
                                        widget.packages.firstWhere(
                                          (package) => package.id == packageId,
                                        ),
                                        currency: currency,
                                      ),
                                style: const TextStyle(fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            RotatedBox(
                              quarterTurns: 1,
                              child: MenuIcon(
                                Icons.chevron_right,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (packageId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '已包含在套餐总价中，份数不重复计费',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                  if (packageId == null) ...[
                    MenuFieldLabel('本次单价', isRequired: widget.requirePrice),
                    MenuPriceField(
                      controller: price,
                      currency: currency,
                      onCurrencyChanged: widget.onCurrencyChanged == null
                          ? null
                          : (value) => setState(() => currency = value),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const MenuFieldLabel('数量'),
                  MenuQuantityField(controller: quantity),
                  if (packageId == null &&
                      amount.isFinite &&
                      amount >= 0 &&
                      count > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '小计',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            '${currency.symbol}${money(amount * count)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  const MenuFieldLabel('备注'),
                  TextField(
                    controller: note,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(hintText: '口味、分量或其他备注'),
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
