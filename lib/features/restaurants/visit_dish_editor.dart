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

Future<VisitDish?> editVisitDish(
  BuildContext context,
  VisitDish item, {
  bool requirePrice = false,
  List<VisitPackage> packages = const [],
}) => Navigator.push<VisitDish>(
  context,
  MaterialPageRoute(
    builder: (_) => _VisitDishEditor(
      item: item,
      requirePrice: requirePrice,
      packages: packages,
    ),
  ),
);

class _VisitDishEditor extends StatefulWidget {
  const _VisitDishEditor({
    required this.item,
    this.requirePrice = false,
    required this.packages,
  });
  final bool requirePrice;
  final List<VisitPackage> packages;
  final VisitDish item;
  @override
  State<_VisitDishEditor> createState() => _VisitDishEditorState();
}

class _VisitDishEditorState extends State<_VisitDishEditor> {
  late final name = TextEditingController(text: widget.item.name);
  late final price = TextEditingController(
    text: widget.requirePrice ? '' : money(widget.item.price),
  );
  late final quantity = TextEditingController(text: '${widget.item.quantity}');
  late final note = TextEditingController(text: widget.item.note);
  late List<String> images = [...widget.item.imagePaths];
  late String? packageId = widget.item.packageId;
  bool leaving = false;
  bool picking = false;
  bool get dirty =>
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
    if (picking) return;
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

  void save() {
    final cost = packageId == null
        ? double.tryParse(price.text.trim())
        : widget.item.price;
    final count = int.tryParse(quantity.text.trim());
    if (name.text.trim().isEmpty) {
      showToast(context, '请填写菜品名称');
      return;
    }
    if (cost == null || !cost.isFinite || cost < 0) {
      showToast(context, '请输入有效的单价');
      return;
    }
    if (count == null || count < 1 || count > 100) {
      showToast(context, '数量应为 1 到 100 份');
      return;
    }
    setState(() => leaving = true);
    Navigator.pop(
      context,
      VisitDish(
        dishId: widget.item.dishId,
        packageId: packageId,
        name: name.text.trim(),
        price: cost,
        quantity: count,
        note: note.text.trim(),
        imagePaths: images,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(price.text) ?? 0;
    final count = int.tryParse(quantity.text) ?? 0;
    return PopScope(
      canPop: leaving || (!dirty && !picking),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('本次点单'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: picking ? null : leave,
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
                    onPressed: picking ? null : save,
                    child: const Text('完成', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: AbsorbPointer(
          absorbing: picking,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  const MenuFieldLabel('菜品名称', isRequired: true),
                  TextField(
                    controller: name,
                    style: const TextStyle(fontSize: 15),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: '填写菜品名称'),
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
                            child: Text(visitPackageLabel(package)),
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
                    MenuPriceField(controller: price),
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
                            '¥${money(amount * count)}',
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
