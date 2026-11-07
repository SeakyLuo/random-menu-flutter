import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'library_widgets.dart';
import 'menu_tag.dart';
import 'tag_name_sheet.dart';
import 'widgets.dart';

class TagSelectionPage extends StatefulWidget {
  const TagSelectionPage({
    super.key,
    required this.selected,
    required this.choices,
    required this.limit,
  });

  final List<String> selected;
  final List<String> choices;
  final int limit;

  @override
  State<TagSelectionPage> createState() => _TagSelectionPageState();
}

class _TagSelectionPageState extends State<TagSelectionPage> {
  late final _selected = [...widget.selected];
  late final _options = {...widget.choices, ...widget.selected}.toList();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(String tag) {
    if (widget.limit == 1) {
      setState(() {
        _selected.clear();
        _selected.add(tag);
      });
    } else if (_selected.length == widget.limit) {
      showToast(context, '最多添加${widget.limit}个标签');
    } else {
      setState(() => _selected.add(tag));
    }
  }

  Future<void> _create() async {
    if (widget.limit > 1 && _selected.length == widget.limit) {
      showToast(context, '最多添加${widget.limit}个标签');
      return;
    }
    final tag = await showTagNameSheet(context, existing: _options);
    if (!mounted || tag == null) return;
    setState(() => _options.insert(0, tag));
    _select(tag);
  }

  Widget _tag(String tag, {required bool selected}) {
    void activate() {
      if (selected) {
        setState(() => _selected.remove(tag));
      } else {
        _select(tag);
      }
    }

    return Semantics(
      label: '${selected ? '移除' : '选择'}标签$tag',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: activate,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: MenuTag(tag, removable: selected, onRemove: activate),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sectionStyle = Theme.of(
      context,
    ).textTheme.labelLarge!.copyWith(color: scheme.onSurfaceVariant);
    final available = _options
        .where((tag) => !_selected.contains(tag))
        .toList();
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: scheme.surface,
        title: const Text('选择标签'),
        actions: [
          PageActionButton(icon: Icons.add, label: '新建标签', onPressed: _create),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final selectedHeight = math.min(
              112 * MediaQuery.textScalerOf(context).scale(14) / 14,
              constraints.maxHeight * .25,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                if (_selected.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: Text('已选', style: sectionStyle)),
                        TextButton(
                          onPressed: () => setState(_selected.clear),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: selectedHeight),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in _selected)
                            _tag(tag, selected: true),
                        ],
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('可选标签', style: sectionStyle),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (available.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in available)
                              _tag(tag, selected: false),
                          ],
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            _options.isEmpty ? '还没有标签，点击右上角＋新建' : '所有标签都已选中',
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: FixedPageActions(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: Text(
                widget.limit == 1
                    ? '完成选择'
                    : '完成 · 已选 ${_selected.length}/${widget.limit}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
