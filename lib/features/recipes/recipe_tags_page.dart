import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import 'recipe_search.dart';

class RecipeTagsPage extends StatelessWidget {
  const RecipeTagsPage({super.key});

  Future<void> _rename(BuildContext context, {String? oldName}) async {
    final store = MenuScope.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _TagNameDialog(initialName: oldName, existing: store.data.recipeTags),
    );
    if (result == null || result == oldName || !context.mounted) return;
    await performAction(
      context,
      () => store.update((data) {
        if (oldName == null) {
          data.recipeTags.add(result);
          return;
        }
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
    await performAction(
      context,
      () => store.update((data) {
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
  }

  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final tags = orderedRecipeTags(store.data);
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          TextButton(
            onPressed: () => _rename(context),
            child: const Text('新增'),
          ),
          PopupMenuButton<String>(
            icon: const MenuIcon(Icons.more_horiz),
            tooltip: '标签排序',
            initialValue: store.data.recipeTagSort,
            onSelected: (sort) => performAction(
              context,
              () => store.update((data) => data.recipeTagSort = sort),
            ),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'default',
                checked: store.data.recipeTagSort == 'default',
                child: const Text('按使用数量排序'),
              ),
              CheckedPopupMenuItem(
                value: 'name',
                checked: store.data.recipeTagSort == 'name',
                child: const Text('按名称排序'),
              ),
            ],
          ),
        ],
      ),
      body: tags.isEmpty
          ? EmptyState(
              icon: Icons.label_outline,
              title: '还没有标签',
              message: '添加常用标签，整理自己的菜谱。',
              actionLabel: '添加标签',
              onAction: () => _rename(context),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  itemCount: tags.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, index) {
                    final tag = tags[index];
                    final count = store.data.recipes
                        .where((r) => r.tags.contains(tag))
                        .length;
                    return ListTile(
                      title: Text(tag),
                      subtitle: Text('$count 道菜谱'),
                      trailing: PopupMenuButton<String>(
                        icon: const MenuIcon(Icons.more_horiz),
                        tooltip: '管理“$tag”',
                        onSelected: (action) => action == 'rename'
                            ? _rename(context, oldName: tag)
                            : _delete(context, tag),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('重命名')),
                          PopupMenuItem(value: 'delete', child: Text('删除标签')),
                        ],
                      ),
                    );
                  },
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialName == null ? '添加标签' : '重命名标签'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 30,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: const InputDecoration(labelText: '标签名称'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );
}
