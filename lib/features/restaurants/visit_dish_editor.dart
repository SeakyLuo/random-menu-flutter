import '../../ui/menu_icon.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'restaurant_dish_editor.dart';
import 'restaurant_images.dart';

Future<VisitDish?> pickVisitDish(BuildContext context, String restaurantId) =>
    Navigator.push<VisitDish>(
      context,
      MaterialPageRoute(
        builder: (_) => _PickDishPage(restaurantId: restaurantId),
      ),
    );
Future<VisitDish?> editVisitDish(
  BuildContext context,
  VisitDish item, {
  bool requirePrice = false,
}) => Navigator.push<VisitDish>(
  context,
  MaterialPageRoute(
    builder: (_) => _VisitDishEditor(item: item, requirePrice: requirePrice),
  ),
);

class _PickDishPage extends StatelessWidget {
  const _PickDishPage({required this.restaurantId});
  final String restaurantId;
  @override
  Widget build(BuildContext context) {
    final restaurant = MenuScope.of(
      context,
    ).data.restaurants.firstWhere((r) => r.id == restaurantId);
    void add() => Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantDishEditor(restaurantId: restaurantId),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择菜品'),
        actions: [
          TextButton.icon(
            onPressed: add,
            icon: const MenuIcon(Icons.add, size: 18),
            label: const Text('新增菜品'),
          ),
        ],
      ),
      body: restaurant.foods.isEmpty
          ? EmptyState(
              icon: Icons.ramen_dining_outlined,
              title: '先记下一道菜',
              message: '添加菜品后，就可以记录本次点单数量和价格。',
              actionLabel: '添加菜品',
              onAction: add,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: restaurant.foods.length,
              itemBuilder: (context, index) {
                final dish = restaurant.foods[index];
                return ListTile(
                  title: Text(dish.name),
                  subtitle: Text('¥${money(dish.price)}'),
                  trailing: const MenuIcon(Icons.add),
                  onTap: () async {
                    final result = await editVisitDish(
                      context,
                      VisitDish(
                        dishId: dish.id,
                        name: dish.name,
                        price: dish.price,
                        quantity: dish.quantity,
                        note: dish.note,
                        imagePaths: [...dish.imagePaths],
                      ),
                    );
                    if (result != null && context.mounted) {
                      Navigator.pop(context, result);
                    }
                  },
                );
              },
            ),
    );
  }
}

class _VisitDishEditor extends StatefulWidget {
  const _VisitDishEditor({required this.item, this.requirePrice = false});
  final bool requirePrice;
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
  bool leaving = false;
  bool picking = false;
  bool get dirty =>
      name.text != widget.item.name ||
      price.text != (widget.requirePrice ? '' : money(widget.item.price)) ||
      quantity.text != '${widget.item.quantity}' ||
      note.text != widget.item.note ||
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
    final cost = double.tryParse(price.text.trim());
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
        appBar: AppBar(
          title: const Text('本次点单'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: picking ? null : leave,
            icon: const MenuIcon(Icons.arrow_back),
          ),
          actions: [
            TextButton(
              onPressed: picking ? null : save,
              child: const Text('完成'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '菜品名称'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '本次单价',
                prefixText: '¥ ',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '数量',
                      suffixText: '份',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '减少一份',
                  onPressed: count > 1
                      ? () => quantity.text = '${count - 1}'
                      : null,
                  icon: const MenuIcon(Icons.remove_circle_outline),
                ),
                IconButton(
                  tooltip: '增加一份',
                  onPressed: count < 100
                      ? () => quantity.text = '${count + 1}'
                      : null,
                  icon: const MenuIcon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (amount.isFinite && amount >= 0 && count > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '小计 ¥${money(amount * count)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: note,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '本次菜品备注'),
            ),
            const SectionTitle('本次菜品照片'),
            RestaurantImages(
              paths: images,
              cover: true,
              onBusyChanged: (value) => setState(() => picking = value),
              onChanged: (v) {
                if (mounted) setState(() => images = v);
              },
            ),
            const SizedBox(height: 16),
            Text(
              '本次单价、数量和照片会保留在用餐记录中。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
