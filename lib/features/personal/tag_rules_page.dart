import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/library_widgets.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import 'tag_rule_editor.dart';

class TagRulesPage extends StatefulWidget {
  const TagRulesPage({super.key});
  @override
  State<TagRulesPage> createState() => _TagRulesPageState();
}

class _TagRulesPageState extends State<TagRulesPage> {
  final _scroll = ScrollController();
  int _visibleCount = 24;
  int _ruleCount = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadMore() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 320 &&
        _visibleCount < _ruleCount) {
      setState(() => _visibleCount = min(_visibleCount + 24, _ruleCount));
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _saving = true);
    await performAction(
      context,
      () => MenuScope.of(context).update((draft) => draft.autoTag = value),
      success: value ? '自动标签已开启' : '自动标签已关闭',
    );
    if (mounted) setState(() => _saving = false);
  }

  void _add() => showTagRuleEditor(context, mode: TagRuleMode.pattern);

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final rules = [
      for (final rule in data.tagRules.entries)
        (
          mode: TagRuleMode.literal,
          key: rule.key,
          keyword: rule.value.join('、'),
          tags: [rule.key],
        ),
      for (final rule in data.patternTagRules.entries)
        (
          mode: TagRuleMode.pattern,
          key: rule.key,
          keyword: rule.key,
          tags: rule.value,
        ),
    ];
    _ruleCount = rules.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMore();
    });
    final colors = Theme.of(context).colorScheme;
    final visible = min(_visibleCount, rules.length);
    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: const Text('自动标签')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        title: const Text(
                          '自动添加标签',
                          style: TextStyle(fontSize: 16),
                        ),
                        value: data.autoTag,
                        onChanged: _saving ? null : _toggle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: rules.isEmpty
                        ? EmptyState(
                            icon: Icons.auto_awesome_outlined,
                            title: '还没有标签规则',
                            message: '添加一条菜名匹配规则，让整理菜谱更轻松。',
                            actionLabel: '添加规则',
                            onAction: _add,
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              100 + MediaQuery.viewPaddingOf(context).bottom,
                            ),
                            itemCount: visible + 2,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    '共 ${rules.length} 条规则',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }
                              if (index == visible + 1) {
                                return visible == rules.length
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Text(
                                          '已显示全部规则',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      )
                                    : const SizedBox(height: 1);
                              }
                              final rule = rules[index - 1];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _RuleRow(
                                  keyword: rule.keyword,
                                  tags: rule.tags,
                                  onTap: () => showTagRuleEditor(
                                    context,
                                    mode: rule.mode,
                                    existingKey: rule.key,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              if (rules.isNotEmpty)
                LibraryFab(label: '添加标签规则', bottom: 20, onPressed: _add),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.keyword,
    required this.tags,
    required this.onTap,
  });
  final String keyword;
  final List<String> tags;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget label(String text) => SizedBox(
      width: 48,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 2,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('关键词'),
                        Expanded(
                          child: Text(
                            keyword,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label('标签'),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: colors.primary.withValues(
                                      alpha: .09,
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.65,
                                      color: colors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MenuIcon(
                Icons.chevron_right,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
