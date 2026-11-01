import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'restaurant_images.dart';

class RestaurantDishEditor extends StatefulWidget {
  const RestaurantDishEditor({
    super.key,
    required this.restaurantId,
    this.dish,
  });
  final String restaurantId;
  final RestaurantDish? dish;
  @override
  State<RestaurantDishEditor> createState() => _RestaurantDishEditorState();
}

class _RestaurantDishEditorState extends State<RestaurantDishEditor> {
  late final name = TextEditingController(text: widget.dish?.name ?? '');
  late final price = TextEditingController(
    text: widget.dish == null || widget.dish!.price == 0
        ? ''
        : money(widget.dish!.price),
  );
  late final quantity = TextEditingController(
    text: '${widget.dish?.quantity ?? 1}',
  );
  late final note = TextEditingController(text: widget.dish?.note ?? '');
  late List<String> images = [...?widget.dish?.imagePaths];
  bool saving = false;
  bool picking = false;
  bool get busy => saving || picking;

  bool leaving = false;
  void changed() => setState(() {});
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

  bool get dirty =>
      name.text != (widget.dish?.name ?? '') ||
      price.text !=
          (widget.dish == null || widget.dish!.price == 0
              ? ''
              : money(widget.dish!.price)) ||
      quantity.text != '${widget.dish?.quantity ?? 1}' ||
      note.text != (widget.dish?.note ?? '') ||
      !listEquals(images, widget.dish?.imagePaths ?? const <String>[]);
  @override
  void initState() {
    super.initState();
    for (final controller in [name, price, quantity, note]) {
      controller.addListener(changed);
    }
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    quantity.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      showToast(context, '请填写菜品名称');
      return;
    }
    final value = price.text.trim().isEmpty
        ? 0.0
        : double.tryParse(price.text.trim());
    if (value == null || !value.isFinite || value < 0) {
      showToast(context, '请输入有效的菜品价格');
      return;
    }
    final count = int.tryParse(quantity.text.trim());
    if (count == null || count < 1 || count > 100) {
      showToast(context, '数量应为 1 到 100 份');
      return;
    }
    final store = MenuScope.of(context);
    final restaurant = store.data.restaurants.firstWhere(
      (r) => r.id == widget.restaurantId,
    );
    if (restaurant.foods.any(
      (d) => d.name == name.text.trim() && d.id != widget.dish?.id,
    )) {
      showToast(context, '这道菜已经添加过了');
      return;
    }
    setState(() => saving = true);
    final success = await performAction(context, () async {
      final savedImages = await Future.wait(
        images.map(
          (path) async => path.startsWith('${store.directory.path}/images/')
              ? path
              : await store.keepImage(path),
        ),
      );
      await store.update((draft) {
        final r = draft.restaurants.firstWhere(
          (r) => r.id == widget.restaurantId,
        );
        final edited = RestaurantDish(
          id: widget.dish?.id ?? newId(),
          name: name.text.trim(),
          price: value,
          quantity: count,
          note: note.text.trim(),
          imagePaths: savedImages,
        );
        if (widget.dish == null) {
          r.foods.add(edited);
        } else {
          r.foods[r.foods.indexWhere((d) => d.id == widget.dish!.id)] = edited;
        }
      });
    });
    if (!mounted) return;
    if (success) {
      showToast(context, '菜品已保存');
      setState(() => leaving = true);
      Navigator.pop(context);
    } else {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || (!dirty && !busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.dish == null ? '添加菜品' : '编辑菜品'),
        leading: IconButton(
          tooltip: '返回',
          onPressed: busy ? null : leave,
          icon: const MenuIcon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : save,
            child: Text(saving ? '保存中' : '保存'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            TextField(
              controller: name,
              autofocus: widget.dish == null,
              decoration: const InputDecoration(labelText: '菜品名称'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '价格',
                prefixText: '¥ ',
                hintText: '选填',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: note,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '口味、分量或推荐程度',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '默认点单数量',
                suffixText: '份',
                helperText: '每次用餐时仍可单独调整，范围 1–100 份',
              ),
            ),
            const SectionTitle('菜品照片'),
            RestaurantImages(
              paths: images,
              cover: true,
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
