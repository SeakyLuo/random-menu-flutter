import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/library_widgets.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_tag_colors.dart';
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

  void _add() => showTagRuleEditor(context, mode: TagRuleMode.pattern);

  @override
  Widget build(BuildContext context) {
    final data = MenuScope.of(context).data;
    final rules = [
      for (final rule in data.tagRules.entries)
        (
          mode: TagRuleMode.literal,
          key: rule.key,
          keywords: rule.value,
          tags: [rule.key],
        ),
      for (final rule in data.patternTagRules.entries)
        (
          mode: TagRuleMode.pattern,
          key: rule.key,
          keywords: [rule.key],
          tags: rule.value,
        ),
    ];
    _ruleCount = rules.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMore();
    });
    final visible = min(_visibleCount, rules.length);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: MenuScrollTitle(
          controller: _scroll,
          child: const Text(
            '自动标签',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Stack(
            fit: StackFit.expand,
            children: [
              rules.isEmpty
                  ? const EmptyState(
                      icon: Icons.auto_awesome_outlined,
                      title: '还没有标签规则',
                      message: '添加一条菜名匹配规则，让整理菜谱更轻松。',
                    )
                  : ListView.separated(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        100 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      itemCount: visible,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final rule = rules[index];
                        return _RuleRow(
                          keywords: rule.keywords,
                          tags: rule.tags,
                          onTap: () => showTagRuleEditor(
                            context,
                            mode: rule.mode,
                            existingKey: rule.key,
                          ),
                        );
                      },
                    ),
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
    required this.keywords,
    required this.tags,
    required this.onTap,
  });
  final List<String> keywords;
  final List<String> tags;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tagColors = MenuTagColors.of(context);
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
                            keywords.join('、'),
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
                                _RuleChip(
                                  text: tag,
                                  background: tagColors.background,
                                  foreground: tagColors.foreground,
                                  border: tagColors.border,
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

class _RuleChip extends StatelessWidget {
  const _RuleChip({
    required this.text,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String text;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.65,
        fontWeight: FontWeight.w500,
        color: foreground,
      ),
    ),
  );
}
