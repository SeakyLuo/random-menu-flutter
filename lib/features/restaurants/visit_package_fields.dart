import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_field_label.dart';
import '../../ui/menu_popup.dart';
import '../../ui/widgets.dart';
import '../media/photo_widget.dart';
import 'restaurant_dish_page.dart';

class VisitPackageFields extends StatelessWidget {
  const VisitPackageFields({
    super.key,
    required this.packages,
    required this.items,
    required this.onChanged,
    required this.onRemove,
  });
  final List<VisitPackage> packages;
  final List<VisitDish> items;
  final ValueChanged<List<VisitPackage>> onChanged;
  final ValueChanged<VisitPackage> onRemove;

  Future<void> edit(BuildContext context, [int? index]) async {
    final result = await showDialog<VisitPackage>(
      context: context,
      builder: (_) =>
          _PackageDialog(package: index == null ? null : packages[index]),
    );
    if (result == null) return;
    final updated = [...packages];
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MenuFieldLabel(
        '套餐',
        minHeight: 44,
        bottomSpacing: 4,
        trailing: IconButton(
          tooltip: '添加套餐',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => edit(context),
          icon: const MenuIcon(Icons.add, size: 20),
        ),
      ),
      for (final (index, package) in packages.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PackageBar(
            key: ValueKey(package.id),
            package: package,
            dishes: items
                .where((dish) => dish.packageId == package.id)
                .toList(),
            onEdit: () => edit(context, index),
            onRemove: () => onRemove(package),
          ),
        ),
    ],
  );
}

class _PackageBar extends StatelessWidget {
  const _PackageBar({
    super.key,
    required this.package,
    required this.dishes,
    required this.onEdit,
    required this.onRemove,
  });

  final VisitPackage package;
  final List<VisitDish> dishes;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).inputDecorationTheme.fillColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: [
              if (dishes.isNotEmpty) ...[
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      primary: false,
                      padding: EdgeInsets.zero,
                      scrollDirection: Axis.horizontal,
                      itemCount: dishes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final dish = dishes[index];
                        return Semantics(
                          label: dish.name,
                          button: true,
                          child: SizedBox.square(
                            dimension: 48,
                            child: GestureDetector(
                              onTap: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => RestaurantDishPage.preview(
                                    dish: dish,
                                    package: package,
                                  ),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: dish.imagePaths.isEmpty
                                    ? ColoredBox(
                                        color: scheme.surfaceContainerHighest,
                                        child: Center(
                                          child: MenuIcon(
                                            Icons.restaurant,
                                            size: 22,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : LocalPhoto(path: dish.imagePaths.first),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: dishes.isEmpty
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      package.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${money(package.totalPrice)}',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              MenuPopupButton<String>(
                tooltip: '套餐操作',
                icon: MenuIcon(
                  Icons.more_horiz,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                onSelected: (action) =>
                    action == 'edit' ? onEdit() : onRemove(),
                itemBuilder: (_) => const [
                  MenuPopupItem(
                    value: 'edit',
                    icon: Icons.edit_outlined,
                    child: Text('编辑套餐'),
                  ),
                  MenuPopupItem(
                    value: 'remove',
                    icon: Icons.delete_outline,
                    destructive: true,
                    child: Text('移除套餐'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageDialog extends StatefulWidget {
  const _PackageDialog({this.package});
  final VisitPackage? package;
  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  late final name = TextEditingController(text: widget.package?.name ?? '');
  late final price = TextEditingController(
    text: widget.package == null ? '' : money(widget.package!.totalPrice),
  );

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty) {
      showToast(context, '请填写套餐名称');
      return;
    }
    final value = double.tryParse(price.text.trim());
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        (value * 100 - (value * 100).round()).abs() > .000001) {
      showToast(context, '请填写有效的套餐总价，最多两位小数');
      return;
    }
    Navigator.pop(
      context,
      VisitPackage(
        id: widget.package?.id ?? newId(),
        name: name.text.trim(),
        totalPrice: value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MenuDialog(
    title: widget.package == null ? '添加套餐' : '编辑套餐',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: '套餐名称'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: price,
          textInputAction: TextInputAction.done,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => save(),
          decoration: const InputDecoration(
            labelText: '套餐总价',
            prefixText: '¥ ',
          ),
        ),
      ],
    ),
    actions: Row(
      children: [
        Expanded(
          child: MenuDialogButton(
            label: '取消',
            role: MenuDialogRole.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MenuDialogButton(label: '保存', onPressed: save),
        ),
      ],
    ),
  );
}
