import 'restaurant_filter.dart';
import 'restaurants_page.dart';
import '../../ui/name_management_sheet.dart';
import '../../ui/menu_field_label.dart';
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
  final _expanded = <String>{};
  final _rowKeys = <String, GlobalKey>{};
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
    final root = name.split('/').first;
    setState(() => _expanded.add(root));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _scrollTo(_displayedNames.indexOf(root), alignment: .15);
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await Scrollable.ensureVisible(
        _rowKeys[name]!.currentContext!,
        alignment: .25,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _rename({String? oldName, String? parent}) async {
    final store = MenuScope.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryNameDialog(
        initialName: oldName,
        parent: parent,
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
    final directCounts = {for (final name in names) name: 0};
    for (final restaurant in data.restaurants) {
      for (final tag in restaurant.categories.toSet()) {
        directCounts[tag] = directCounts[tag]! + 1;
      }
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
    final roots = names.where((name) => !name.contains('/')).toList();
    final children = {
      for (final root in roots)
        root: names.where((name) => name.startsWith('$root/')).toList(),
    };
    _displayedNames = roots;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: MenuScrollTitle(
          onTap: () => _scrollTo(0),
          child: MenuTitleLine(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(child: Text('菜系管理')),
              const SizedBox(width: 10),
              Text(
                '${names.length} 个',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
                      itemCount: roots.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final root = roots[index];
                        final descendants = children[root]!;
                        final expanded = _expanded.contains(root);
                        return Material(
                          key: ValueKey(root),
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(2),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _categoryRow(
                                root,
                                counts[root]!,
                                root: true,
                                expanded: expanded,
                                hasChildren: descendants.isNotEmpty,
                              ),
                              if (expanded && descendants.isNotEmpty) ...[
                                Divider(
                                  height: 1,
                                  thickness: .5,
                                  indent: 16,
                                  endIndent: 16,
                                  color: colors.outlineVariant.withValues(
                                    alpha: .45,
                                  ),
                                ),
                                for (final child in descendants)
                                  _categoryRow(child, counts[child]!),
                                if (directCounts[root]! > 0)
                                  _categoryRow(
                                    root,
                                    directCounts[root]!,
                                    other: true,
                                  ),
                              ],
                            ],
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

  Future<void> _manage(String name, {bool other = false}) async {
    final action = await showNameManagementSheet(
      context,
      name: other ? '${tagPathLabel(name)} · 其他' : tagPathLabel(name),
      deleteLabel: '删除菜系',
      addChildLabel: other ? null : '添加细分菜系',
      viewLabel: '查看餐厅',
      allowEditing: !other,
    );
    if (!mounted) return;
    switch (action) {
      case NameManagementAction.view:
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => RestaurantsPage.filtered(
              query: RestaurantQuery(
                categories: [name],
                exactCategories: other,
              ),
            ),
          ),
        );
      case NameManagementAction.rename:
        await _rename(oldName: name);
      case NameManagementAction.delete:
        await _delete(name);
      case NameManagementAction.addChild:
        await _rename(parent: name);
      case null:
        break;
    }
  }

  Widget _categoryRow(
    String name,
    int count, {
    bool root = false,
    bool other = false,
    bool expanded = false,
    bool hasChildren = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        key: _rowKeys.putIfAbsent(
          other ? '$name\u0000other' : name,
          GlobalKey.new,
        ),
        children: [
          Expanded(
            child: InkWell(
              onTap: _saving ? null : () => _manage(name, other: other),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: root ? 52 : 44),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    root
                        ? 16
                        : other
                        ? 28
                        : 28 + 12.0 * (name.split('/').length - 2),
                    root ? 10 : 6,
                    12,
                    root ? 10 : 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: other ? '其他' : tagPathLabel(name),
                                style: TextStyle(
                                  fontSize: root ? 16 : 14,
                                  height: 1.4,
                                  fontWeight: root
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              TextSpan(
                                text: '  $count 家',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (root && hasChildren)
            SizedBox(
              width: 44,
              child: Tooltip(
                message: '${expanded ? '收起' : '展开'}${tagPathLabel(name)}',
                child: InkWell(
                  onTap: _saving
                      ? null
                      : () => setState(() {
                          if (!_expanded.add(name)) _expanded.remove(name);
                        }),
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: colors.primary.withValues(alpha: .1),
                  hoverColor: colors.primary.withValues(alpha: .05),
                  child: Center(
                    child: AnimatedRotation(
                      turns: expanded ? .5 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: MenuIcon(
                        Icons.expand_more,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.initialName,
    required this.existing,
    this.parent,
  });
  final String? initialName;
  final String? parent;
  final List<String> existing;
  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late String _parent = widget.parent ?? '';
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
    if (widget.initialName == null && name.contains('/')) {
      showToast(context, '名称只需填写当前菜系，所属菜系请在下拉框选择');
      return;
    }
    final value = widget.initialName == null && _parent.isNotEmpty
        ? '$_parent/$name'
        : name;
    if (value != widget.initialName && widget.existing.contains(value)) {
      showToast(context, '该菜系已存在');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => MenuDialog(
    title: widget.parent != null
        ? '添加${tagPathLabel(widget.parent!)}细分菜系'
        : widget.initialName == null
        ? '新增菜系'
        : '重命名菜系',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.initialName == null) ...[
          const MenuFieldLabel('所属菜系', bottomSpacing: 6),
          MenuPopupButton<String>(
            tooltip: '选择所属菜系',
            matchAnchorWidth: true,
            borderRadius: BorderRadius.circular(12),
            itemBuilder: (_) => [
              MenuPopupItem(
                value: '',
                icon: Icons.restaurant,
                selected: _parent.isEmpty,
                child: const Text('无'),
              ),
              for (final parent in widget.existing)
                MenuPopupItem(
                  value: parent,
                  icon: Icons.restaurant,
                  selected: _parent == parent,
                  child: Text(parent.replaceAll('/', ' · ')),
                ),
            ],
            onSelected: (value) => setState(() => _parent = value),
            child: InputDecorator(
              decoration: const InputDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _parent.isEmpty ? '无' : _parent.replaceAll('/', ' · '),
                      style: const TextStyle(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const MenuIcon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const MenuFieldLabel('菜系名称', bottomSpacing: 6),
        ],
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: widget.initialName == null ? '例如：广式点心' : '例如：烤肉/日本烤肉',
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
          child: MenuDialogButton(label: '保存', onPressed: _submit),
        ),
      ],
    ),
  );
}
