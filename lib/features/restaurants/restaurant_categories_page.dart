import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/library_widgets.dart';
import '../../ui/menu_popup.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';

List<String> restaurantCategoryNames(MenuData data) => {
  ...data.restaurantCategories,
  for (final restaurant in data.restaurants)
    if (restaurant.category.isNotEmpty) restaurant.category,
}.toList()..sort();

class RestaurantCategoriesPage extends StatefulWidget {
  const RestaurantCategoriesPage({
    super.key,
    required this.onRenamed,
    required this.onDeleted,
  });
  final void Function(String oldName, String newName) onRenamed;
  final ValueChanged<String> onDeleted;
  @override
  State<RestaurantCategoriesPage> createState() =>
      _RestaurantCategoriesPageState();
}

class _RestaurantCategoriesPageState extends State<RestaurantCategoriesPage> {
  bool _saving = false;

  Future<void> _rename({String? oldName}) async {
    final store = MenuScope.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryNameDialog(
        initialName: oldName,
        existing: restaurantCategoryNames(store.data),
      ),
    );
    if (!mounted || result == null || result == oldName) return;
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => store.update(MenuWriteScope.restaurantsAll, (data) {
        if (restaurantCategoryNames(data).contains(result)) {
          throw StateError('该菜系已存在');
        }
        if (oldName != null) {
          data.restaurantCategoryIds[result] = data.restaurantCategoryIds
              .remove(oldName)!;
        }
        data.restaurantCategories = {
          for (final name in restaurantCategoryNames(data))
            name == oldName ? result : name,
          result,
        }.toList();
        if (oldName != null) {
          for (final restaurant in data.restaurants) {
            if (restaurant.category == oldName) restaurant.category = result;
          }
        }
      }),
      success: oldName == null ? '菜系已添加' : '菜系已重命名',
    );
    if (saved && oldName != null) widget.onRenamed(oldName, result);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _delete(String name) async {
    final store = MenuScope.of(context);
    final count = store.data.restaurants
        .where((r) => r.category == name)
        .length;
    if (!await confirmAction(
      context,
      title: '删除菜系“$name”？',
      message: count == 0 ? '删除后不再出现在菜系建议中。' : '会清空 $count 家餐厅的菜系，餐厅和用餐记录仍然保留。',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => store.update(MenuWriteScope.restaurantsAll, (data) {
        data.restaurantCategories.remove(name);
        for (final restaurant in data.restaurants) {
          if (restaurant.category == name) restaurant.category = '';
        }
      }),
      success: '菜系已删除',
    );
    if (saved) widget.onDeleted(name);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final names = restaurantCategoryNames(data);
    final counts = {for (final name in names) name: 0};
    for (final restaurant in data.restaurants) {
      if (restaurant.category.isNotEmpty) {
        counts[restaurant.category] = counts[restaurant.category]! + 1;
      }
    }
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('菜系管理')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Stack(
            fit: StackFit.expand,
            children: [
              names.isEmpty
                  ? const Center(child: Text('还没有菜系，点击右下角 ＋ 添加'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                      itemCount: names.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final name = names[index];
                        return Material(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(2),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(
                              left: 16,
                              right: 4,
                            ),
                            onTap: _saving
                                ? null
                                : () => _rename(oldName: name),
                            title: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  ${counts[name]} 家',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: MenuPopupButton<String>(
                              icon: MenuIcon(
                                Icons.more_horiz,
                                size: 18,
                                color: colors.onSurfaceVariant,
                              ),
                              tooltip: '管理$name',
                              enabled: !_saving,
                              onSelected: (action) => action == 'rename'
                                  ? _rename(oldName: name)
                                  : _delete(name),
                              itemBuilder: (_) => const [
                                MenuPopupItem(
                                  value: 'rename',
                                  icon: Icons.edit_outlined,
                                  child: Text('重命名'),
                                ),
                                MenuPopupItem(
                                  value: 'delete',
                                  icon: Icons.delete_outline,
                                  destructive: true,
                                  child: Text('删除菜系'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              LibraryFab(
                label: '新增菜系',
                bottom: 20,
                onPressed: _saving ? null : () => _rename(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.initialName,
    required this.existing,
  });
  final String? initialName;
  final List<String> existing;
  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, '请填写菜系名称');
      return;
    }
    if (name != widget.initialName && widget.existing.contains(name)) {
      showToast(context, '该菜系已存在');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => MenuDialog(
    title: widget.initialName == null ? '新增菜系' : '重命名菜系',
    content: TextField(
      controller: _name,
      autofocus: true,
      maxLength: 30,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: const InputDecoration(hintText: '输入菜系名称'),
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
          child: MenuDialogButton(label: '保存', onPressed: _submit),
        ),
      ],
    ),
  );
}
