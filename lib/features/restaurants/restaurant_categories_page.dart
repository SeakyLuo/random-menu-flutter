import '../../core/tag_path.dart';
import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/library_widgets.dart';
import '../../ui/menu_popup.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';

List<String> restaurantCategoryNames(MenuData data) => {
  for (final tag in [
    ...data.restaurantCategories,
    for (final restaurant in data.restaurants) ...restaurant.categories,
  ])
    ...tagPathPrefixes(tag),
}.toList()..sort();

class RestaurantCategoriesPage extends StatefulWidget {
  const RestaurantCategoriesPage({super.key});
  @override
  State<RestaurantCategoriesPage> createState() =>
      _RestaurantCategoriesPageState();
}

class _RestaurantCategoriesPageState extends State<RestaurantCategoriesPage> {
  bool _saving = false;
  bool _alphabetical = true;
  final _scroll = ItemScrollController();
  List<String> _displayedNames = [];

  Future<void> _scrollTo(int index, {double alignment = 0}) async {
    if (_displayedNames.isEmpty) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(index: index, alignment: alignment);
    } else {
      await _scroll.scrollTo(
        index: index,
        alignment: alignment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _reveal(String name) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _scrollTo(_displayedNames.indexOf(name), alignment: .25);
    });
  }

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
          final renamed = {
            for (final entry in data.restaurantCategoryIds.entries)
              renamedTagPath(entry.key, oldName, result): entry.value,
          };
          data.restaurantCategoryIds = renamed;
        }
        data.restaurantCategories = {
          for (final name in restaurantCategoryNames(data))
            oldName == null ? name : renamedTagPath(name, oldName, result),
          result,
        }.toList();
        if (oldName != null) {
          for (final restaurant in data.restaurants) {
            restaurant.categories = [
              for (final tag in restaurant.categories)
                renamedTagPath(tag, oldName, result),
            ];
          }
        }
      }),
      success: oldName == null ? '菜系已添加' : '菜系已重命名',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) _reveal(result);
  }

  Future<void> _delete(String name) async {
    final store = MenuScope.of(context);
    final count = store.data.restaurants
        .where((r) => r.categories.any((tag) => tagPathContains(name, tag)))
        .length;
    if (!await confirmAction(
      context,
      title: '删除菜系“$name”及其细分菜系？',
      message: count == 0
          ? '删除后不再出现在菜系建议中。'
          : '会从 $count 家餐厅移除此菜系及其细分菜系，其他菜系、餐厅和消费记录保留。',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    await performAction(
      context,
      () => store.update(MenuWriteScope.restaurantsAll, (data) {
        data.restaurantCategories.removeWhere(
          (tag) => tagPathContains(name, tag),
        );
        for (final restaurant in data.restaurants) {
          restaurant.categories.removeWhere(
            (tag) => tagPathContains(name, tag),
          );
        }
      }),
      success: '菜系已删除',
    );
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final names = restaurantCategoryNames(data);
    final counts = {for (final name in names) name: 0};
    for (final restaurant in data.restaurants) {
      for (final tag in {
        for (final selected in restaurant.categories)
          ...tagPathPrefixes(selected),
      }) {
        counts[tag] = counts[tag]! + 1;
      }
    }
    final parts = {for (final name in names) name: name.split('/')};
    final letters = {
      for (final part in parts.values.expand((parts) => parts).toSet())
        part: PinyinHelper.getPinyinE(part, separator: '').toLowerCase(),
    };
    names.sort((a, b) {
      final left = parts[a]!;
      final right = parts[b]!;
      for (var i = 0; i < left.length && i < right.length; i++) {
        if (left[i] == right[i]) continue;
        if (!_alphabetical) {
          final leftCount = counts[left.take(i + 1).join('/')]!;
          final rightCount = counts[right.take(i + 1).join('/')]!;
          final order = rightCount.compareTo(leftCount);
          if (order != 0) return order;
        }
        final order = letters[left[i]]!.compareTo(letters[right[i]]!);
        return order != 0 ? order : left[i].compareTo(right[i]);
      }
      return left.length.compareTo(right.length);
    });
    _displayedNames = names;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: MenuScrollTitle(
          onTap: () => _scrollTo(0),
          child: const Text('菜系管理'),
        ),
        actions: [
          MenuPopupButton<bool>(
            icon: const MenuIcon(Icons.sort_by_alpha),
            tooltip: '菜系排序',
            enabled: !_saving,
            onSelected: (value) {
              setState(() => _alphabetical = value);
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (mounted) await _scrollTo(0);
              });
            },
            itemBuilder: (_) => [
              MenuPopupItem(
                value: true,
                icon: Icons.sort_by_alpha,
                selected: _alphabetical,
                child: const Text('按字母排序'),
              ),
              MenuPopupItem(
                value: false,
                icon: Icons.bar_chart,
                selected: !_alphabetical,
                child: const Text('按使用数量排序'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Stack(
            fit: StackFit.expand,
            children: [
              names.isEmpty
                  ? const Center(child: Text('还没有菜系，点击右下角 ＋ 添加'))
                  : ScrollablePositionedList.separated(
                      itemScrollController: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                      itemCount: names.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final name = names[index];
                        return Material(
                          key: ValueKey(name),
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(2),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: EdgeInsets.only(
                              left: 16 + 12.0 * (name.split('/').length - 1),
                              right: 4,
                            ),
                            onTap: _saving
                                ? null
                                : () => _rename(oldName: name),
                            title: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: tagPathLabel(name),
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
    if (name.split('/').any((part) => part.isEmpty || part.trim() != part)) {
      showToast(context, '请填写完整的菜系名称，例如：烤肉/日本烤肉');
      return;
    }
    final value = widget.initialName == null
        ? inferredTagPath(name, widget.existing)
        : name;
    if (value != widget.initialName && widget.existing.contains(value)) {
      showToast(context, '该菜系已存在');
      return;
    }
    Navigator.pop(context, value);
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
      decoration: const InputDecoration(hintText: '例如：烤肉/日本烤肉'),
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
