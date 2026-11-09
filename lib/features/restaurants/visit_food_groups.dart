import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_field_label.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_popup.dart';
import '../../ui/menu_tag.dart';
import '../../ui/widgets.dart';
import 'visit_dish_editor_row.dart';

class VisitFoodGroups extends StatelessWidget {
  const VisitFoodGroups({
    super.key,
    required this.items,
    required this.packages,
    required this.onEdit,
    required this.onRemove,
    required this.onReorder,
    required this.onEditPackage,
    required this.onRemovePackage,
    required this.onAdd,
    required this.onQuickAdd,
  });

  final List<VisitDish> items;
  final List<VisitPackage> packages;
  final ValueChanged<VisitDish> onEdit;
  final ValueChanged<VisitDish> onRemove;
  final void Function(String?, int, int) onReorder;
  final ValueChanged<VisitPackage> onEditPackage;
  final ValueChanged<VisitPackage> onRemovePackage;
  final ValueChanged<String?> onAdd;
  final ValueChanged<String?> onQuickAdd;

  Widget rows(List<VisitDish> dishes, VisitPackage? package) =>
      SliverReorderableList(
        key: ValueKey(package?.id),
        itemCount: dishes.length,
        onReorderItem: (from, to) => onReorder(package?.id, from, to),
        proxyDecorator: (child, index, animation) => child,
        itemBuilder: (context, index) {
          final dish = dishes[index];
          return VisitDishEditorRow(
            key: ObjectKey(dish),
            dish: dish,
            package: package,
            index: index,
            onEdit: () => onEdit(dish),
            onRemove: () => onRemove(dish),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final grouped = <String?, List<VisitDish>>{};
    for (final dish in items) {
      (grouped[dish.packageId] ??= []).add(dish);
    }
    final singles = grouped[null] ?? [];
    return SliverMainAxisGroup(
      slivers: [
        for (final package in packages) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: _PackageHeader(
                package: package,
                count: grouped[package.id]?.length ?? 0,
                onEdit: () => onEditPackage(package),
                onRemove: () => onRemovePackage(package),
                onAdd: () => onAdd(package.id),
                onQuickAdd: () => onQuickAdd(package.id),
              ),
            ),
          ),
          rows(grouped[package.id] ?? [], package),
        ],
        if (packages.isNotEmpty && singles.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: MenuFieldLabel(
                '单点 · ${singles.length} 道',
                minHeight: 44,
                bottomSpacing: 0,
                trailing: _AddFoodButton(
                  onAdd: () => onAdd(null),
                  onQuickAdd: () => onQuickAdd(null),
                ),
              ),
            ),
          ),
        rows(singles, null),
      ],
    );
  }
}

class _PackageHeader extends StatelessWidget {
  const _PackageHeader({
    required this.package,
    required this.count,
    required this.onEdit,
    required this.onRemove,
    required this.onAdd,
    required this.onQuickAdd,
  });

  final VisitPackage package;
  final int count;
  final VoidCallback onEdit, onRemove, onAdd, onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.inputDecorationTheme.fillColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
          child: Column(
            children: [
              Row(
                children: [
                  const MenuTag('套餐', compact: true, selected: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      package.name,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MenuPopupButton<String>(
                    tooltip: '套餐操作',
                    buttonBuilder: (open) => IconButton(
                      tooltip: '套餐操作',
                      onPressed: open,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const MenuIcon(Icons.more_horiz, size: 20),
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
                        child: Text('解除套餐'),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '¥${money(package.totalPrice)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$count 道菜',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _AddFoodButton(onAdd: onAdd, onQuickAdd: onQuickAdd),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFoodButton extends StatelessWidget {
  const _AddFoodButton({required this.onAdd, required this.onQuickAdd});
  final VoidCallback onAdd, onQuickAdd;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '添加菜品，长按从照片快速添加',
    triggerMode: TooltipTriggerMode.manual,
    child: TextButton.icon(
      onPressed: onAdd,
      onLongPress: onQuickAdd,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      icon: const MenuIcon(Icons.add, size: 15),
      label: const Text('菜品'),
    ),
  );
}
