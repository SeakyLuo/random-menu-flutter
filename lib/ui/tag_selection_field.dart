import 'package:flutter/material.dart';
import 'menu_icon.dart';
import 'widgets.dart';

class TagSelectionField extends StatelessWidget {
  const TagSelectionField({
    super.key,
    required this.selected,
    required this.choices,
    required this.onChanged,
    this.busy = false,
    this.label = '标签',
    this.limit = 10,
  });
  final List<String> selected;
  final List<String> choices;
  final ValueChanged<List<String>> onChanged;
  final bool busy;
  final String label;
  final int limit;

  Future<void> _open(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => _TagSelectionPage(
          selected: selected,
          choices: choices,
          limit: limit,
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton.icon(
            onPressed: busy ? null : () => _open(context),
            icon: const MenuIcon(Icons.add, size: 17),
            label: const Text('添加'),
          ),
        ],
      ),
      if (selected.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in selected)
              _SelectedTag(
                tag: tag,
                onRemove: busy
                    ? null
                    : () => onChanged(
                        selected.where((value) => value != tag).toList(),
                      ),
              ),
          ],
        ),
      ],
    ],
  );
}

class _SelectedTag extends StatelessWidget {
  const _SelectedTag({required this.tag, required this.onRemove});
  final String tag;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '移除标签$tag',
      child: TextButton(
        onPressed: onRemove,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: colors.primary.withValues(alpha: .1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Flexible(child: Text(tag)),
            const MenuIcon(Icons.close, size: 14),
          ],
        ),
      ),
    );
  }
}

class _TagSelectionPage extends StatefulWidget {
  const _TagSelectionPage({
    required this.selected,
    required this.choices,
    required this.limit,
  });
  final List<String> selected;
  final List<String> choices;
  final int limit;
  @override
  State<_TagSelectionPage> createState() => _TagSelectionPageState();
}

class _TagSelectionPageState extends State<_TagSelectionPage> {
  late final _selected = [...widget.selected];
  late final _options = {...widget.choices, ...widget.selected}.toList();
  final _query = TextEditingController();
  final _scroll = ScrollController();
  String get _keyword => _query.text.trim();
  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toggle(String tag) {
    if (_selected.contains(tag)) {
      setState(() => _selected.remove(tag));
    } else if (widget.limit == 1) {
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

  void _create() {
    if (widget.limit > 1 && _selected.length == widget.limit) {
      showToast(context, '最多添加${widget.limit}个标签');
      return;
    }
    final tag = _keyword;
    setState(() => _options.insert(0, tag));
    _toggle(tag);
    _query.clear();
    setState(() {});
    _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _options
        .where((tag) => tag.toLowerCase().contains(_keyword.toLowerCase()))
        .toList();
    final canCreate = _keyword.isNotEmpty && !_options.contains(_keyword);
    return Scaffold(
      appBar: AppBar(title: const Text('选择标签')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _query,
                maxLength: 20,
                decoration: const InputDecoration(
                  hintText: '搜索或新建标签',
                  counterText: '',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(12),
                    child: MenuIcon(Icons.search, size: 20),
                  ),
                ),
                onChanged: (_) {
                  setState(() {});
                  _scroll.jumpTo(0);
                },
              ),
            ),
            if (_selected.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final tag in _selected)
                      _SelectedTag(tag: tag, onRemove: () => _toggle(tag)),
                  ],
                ),
              ),
            if (canCreate)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _create,
                    icon: const MenuIcon(Icons.add, size: 18),
                    label: Text('新建“$_keyword”标签'),
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (matches.isEmpty)
                    Center(
                      child: Text(
                        _keyword.isEmpty ? '输入名称，新建第一个标签' : '没有匹配的标签',
                      ),
                    ),
                  ListView.builder(
                    controller: _scroll,
                    itemExtent: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final tag = matches[index];
                      return CheckboxListTile(
                        title: Text(
                          tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: _selected.contains(tag),
                        onChanged: (_) => _toggle(tag),
                        dense: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FilledButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: Text('完成 · 已选 ${_selected.length}'),
          ),
        ),
      ),
    );
  }
}
