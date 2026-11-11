import '../../ui/name_management_sheet.dart';
import '../../ui/menu_popup.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../ui/library_widgets.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import 'recipe_search.dart';

class RecipeTagsPage extends StatefulWidget {
  const RecipeTagsPage({super.key});

  @override
  State<RecipeTagsPage> createState() => _RecipeTagsPageState();
}

class _RecipeTagsPageState extends State<RecipeTagsPage> {
  bool _saving = false;
  final _scroll = ItemScrollController();
  List<String> _displayedTags = [];

  Future<void> _scrollTo(int index, {double alignment = 0}) async {
    if (_displayedTags.isEmpty) return;
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

  void _reveal(String tag) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _scrollTo(_displayedTags.indexOf(tag), alignment: .25);
    });
  }

  Future<void> _sort(String sort) async {
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => MenuScope.of(
        context,
      ).update(MenuWriteScope.settings, (data) => data.recipeTagSort = sort),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) await _scrollTo(0);
      });
    }
  }

  Future<void> _rename(BuildContext context, {String? oldName}) async {
    final store = MenuScope.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _TagNameDialog(initialName: oldName, existing: store.data.recipeTags),
    );
    if (result == null || result == oldName || !context.mounted) return;
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => store.update(MenuWriteScope.recipesAll, (data) {
        if (oldName == null) {
          data.recipeTags.add(result);
          return;
        }
        data.recipeTagIds[result] = data.recipeTagIds.remove(oldName)!;
        data.recipeTags[data.recipeTags.indexOf(oldName)] = result;
        for (final recipe in data.recipes) {
          recipe.tags = recipe.tags
              .map((tag) => tag == oldName ? result : tag)
              .toSet()
              .toList();
        }
        final savedDraft = data.recipeDraft;
        if (savedDraft != null) {
          savedDraft.tags = savedDraft.tags
              .map((tag) => tag == oldName ? result : tag)
              .toSet()
              .toList();
        }
        if (data.tagRules.containsKey(oldName)) {
          data.tagRules[result] = {
            ...?data.tagRules[result],
            ...data.tagRules.remove(oldName)!,
          }.toList();
        }
        data.patternTagRules = data.patternTagRules.map(
          (pattern, tags) => MapEntry(
            pattern,
            tags.map((tag) => tag == oldName ? result : tag).toSet().toList(),
          ),
        );
      }),
      success: oldName == null ? '标签已添加' : '标签已重命名',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) _reveal(result);
  }

  Future<void> _delete(BuildContext context, String tag) async {
    final store = MenuScope.of(context);
    if (!await confirmAction(
      context,
      title: '删除标签“$tag”？',
      message: '会从所有菜谱、草稿和自动标签规则中移除这个标签，菜谱仍然保留。',
    )) {
      return;
    }
    if (!context.mounted) return;
    setState(() => _saving = true);
    await performAction(
      context,
      () => store.update(MenuWriteScope.recipesAll, (data) {
        data.recipeTags.remove(tag);
        for (final recipe in data.recipes) {
          recipe.tags.remove(tag);
        }
        data.recipeDraft?.tags.remove(tag);
        data.tagRules.remove(tag);
        data.patternTagRules = data.patternTagRules.map(
          (pattern, tags) =>
              MapEntry(pattern, tags.where((value) => value != tag).toList()),
        )..removeWhere((_, tags) => tags.isEmpty);
      }),
      success: '标签已删除',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final tags = orderedRecipeTags(store.data);
    _displayedTags = tags;
    final counts = {for (final tag in tags) tag: 0};
    for (final recipe in store.data.recipes) {
      for (final tag in recipe.tags) {
        counts[tag] = counts[tag]! + 1;
      }
    }
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: MenuScrollTitle(
          onTap: () => _scrollTo(0),
          child: MenuTitleLine(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(child: Text('标签管理')),
              const SizedBox(width: 10),
              Text(
                '${tags.length} 个',
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
          MenuPopupButton<String>(
            icon: const MenuIcon(Icons.sort_by_alpha),
            tooltip: '标签排序',
            enabled: !_saving,
            onSelected: _sort,
            itemBuilder: (_) => [
              MenuPopupItem(
                icon: Icons.sort_by_alpha,
                value: 'name',
                selected: store.data.recipeTagSort == 'name',
                child: const Text('按字母排序'),
              ),
              MenuPopupItem(
                icon: Icons.bar_chart,
                value: 'default',
                selected: store.data.recipeTagSort == 'default',
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
              tags.isEmpty
                  ? const Center(child: Text('还没有标签，点击右下角 ＋ 添加'))
                  : ScrollablePositionedList.separated(
                      itemScrollController: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                      itemCount: tags.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, index) {
                        final tag = tags[index];
                        return Material(
                          key: ValueKey(tag),
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(2),
                          clipBehavior: Clip.antiAlias,
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _saving
                                        ? null
                                        : () => _rename(context, oldName: tag),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: tag,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                height: 1.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '  ${counts[tag]} 道',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  child: Tooltip(
                                    message: '管理$tag',
                                    child: InkWell(
                                      onTap: _saving
                                          ? null
                                          : () async {
                                              final action =
                                                  await showNameManagementSheet(
                                                    context,
                                                    name: tag,
                                                    deleteLabel: '删除标签',
                                                  );
                                              if (!context.mounted) return;
                                              switch (action) {
                                                case NameManagementAction
                                                    .rename:
                                                  await _rename(
                                                    context,
                                                    oldName: tag,
                                                  );
                                                case NameManagementAction
                                                    .delete:
                                                  await _delete(context, tag);
                                                case NameManagementAction
                                                    .addChild:
                                                case null:
                                                  break;
                                              }
                                            },
                                      splashFactory: NoSplash.splashFactory,
                                      highlightColor: colors.primary.withValues(
                                        alpha: .1,
                                      ),
                                      hoverColor: colors.primary.withValues(
                                        alpha: .05,
                                      ),
                                      child: Center(
                                        child: MenuIcon(
                                          Icons.more_horiz,
                                          size: 18,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              LibraryFab(
                label: '新增标签',
                bottom: 20,
                onPressed: _saving ? null : () => _rename(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagNameDialog extends StatefulWidget {
  const _TagNameDialog({required this.initialName, required this.existing});
  final String? initialName;
  final List<String> existing;
  @override
  State<_TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<_TagNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      showToast(context, '请填写标签名称');
      return;
    }
    if (name.contains(',') || name.contains('，')) {
      showToast(context, '标签名称不能包含逗号');
      return;
    }
    if (name != widget.initialName && widget.existing.contains(name)) {
      showToast(context, '该标签已存在');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => MenuDialog(
    title: widget.initialName == null ? '新增标签' : '重命名标签',
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 30,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: const InputDecoration(hintText: '例如：家常菜'),
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
