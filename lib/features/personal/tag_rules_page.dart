import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import 'tag_rule_editor.dart';

class TagRulesPage extends StatelessWidget {
  const TagRulesPage({super.key});

  Future<void> _add(BuildContext context) async {
    final mode = await showDialog<TagRuleMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择规则类型'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, TagRuleMode.literal),
            child: const ListTile(
              title: Text('关键词'),
              subtitle: Text('菜名包含关键词时添加标签'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, TagRuleMode.pattern),
            child: const ListTile(
              title: Text('正则'),
              subtitle: Text('使用表达式匹配菜名'),
            ),
          ),
        ],
      ),
    );
    if (mode == null || !context.mounted) return;
    await showTagRuleEditor(context, mode: mode);
  }

  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('自动标签'),
          actions: [
            IconButton(
              tooltip: '添加规则',
              onPressed: () => _add(context),
              icon: const MenuIcon(Icons.add),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: SwitchListTile(
                  title: const Text('自动补充标签'),
                  subtitle: const Text('未填写标签时，保存菜谱会根据名称匹配规则'),
                  value: store.data.autoTag,
                  onChanged: (value) => performAction(
                    context,
                    () => store.update((draft) => draft.autoTag = value),
                    success: value ? '自动标签已开启' : '自动标签已关闭',
                  ),
                ),
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: '关键词'),
                Tab(text: '正则'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _RulesList(mode: TagRuleMode.literal),
                  _RulesList(mode: TagRuleMode.pattern),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesList extends StatelessWidget {
  const _RulesList({required this.mode});
  final TagRuleMode mode;
  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final rules = mode == TagRuleMode.literal
        ? store.data.tagRules
        : store.data.patternTagRules;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          mode == TagRuleMode.literal
              ? '名称包含任一关键词就添加对应标签，英文区分大小写。'
              : '名称包含表达式原文字，或被正则表达式完整匹配时，添加指定标签。此模式也用于保留旧版规则。',
        ),
        const SizedBox(height: 8),
        Text(
          '规则只影响之后保存且未填标签的菜谱，不改动已有标签。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (rules.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              children: [
                const MenuIcon(Icons.auto_awesome_outlined, size: 40),
                const SizedBox(height: 16),
                Text(mode == TagRuleMode.literal ? '还没有关键词规则' : '还没有正则规则'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => showTagRuleEditor(context, mode: mode),
                  child: const Text('添加规则'),
                ),
              ],
            ),
          ),
        for (final rule in rules.entries)
          Card(
            child: ListTile(
              title: Text(rule.key),
              subtitle: Text(
                '${mode == TagRuleMode.literal ? '关键词' : '添加标签'}：${rule.value.join('、')}',
              ),
              onTap: () =>
                  showTagRuleEditor(context, mode: mode, existingKey: rule.key),
              trailing: IconButton(
                tooltip: '删除规则',
                icon: const MenuIcon(Icons.delete_outline),
                onPressed: () => _delete(context, rule.key),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, String key) async {
    final store = MenuScope.of(context);
    if (!await confirmAction(
          context,
          title: '删除规则？',
          message: '删除“$key”的匹配规则？已有菜谱和标签会保留。',
        ) ||
        !context.mounted) {
      return;
    }
    await performAction(
      context,
      () => store.update((draft) {
        (mode == TagRuleMode.literal ? draft.tagRules : draft.patternTagRules)
            .remove(key);
      }),
      success: '规则已删除',
    );
  }
}
