import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/tag_patterns.dart';
import '../../ui/widgets.dart';

enum TagRuleMode { literal, pattern }

Future<void> showTagRuleEditor(
  BuildContext context, {
  required TagRuleMode mode,
  String? existingKey,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _TagRuleEditor(mode: mode, existingKey: existingKey),
);

class _TagRuleEditor extends StatefulWidget {
  const _TagRuleEditor({required this.mode, this.existingKey});
  final TagRuleMode mode;
  final String? existingKey;
  @override
  State<_TagRuleEditor> createState() => _TagRuleEditorState();
}

class _TagRuleEditorState extends State<_TagRuleEditor> {
  final _key = TextEditingController();
  final _values = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool get _pattern => widget.mode == TagRuleMode.pattern;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final rules = _pattern
          ? MenuScope.of(context).data.patternTagRules
          : MenuScope.of(context).data.tagRules;
      _key.text = widget.existingKey ?? '';
      _values.text = widget.existingKey == null
          ? ''
          : rules[widget.existingKey]!.join('、');
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _values.dispose();
    super.dispose();
  }

  List<String> _split(String value) => value
      .split(RegExp('[、,，\n]'))
      .map((word) => word.trim())
      .where((word) => word.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _save() async {
    final store = MenuScope.of(context);
    final key = _pattern ? _key.text : _key.text.trim();
    final values = _split(_values.text);
    if (key.isEmpty) {
      showToast(context, _pattern ? '请输入表达式' : '请输入标签名称');
      return;
    }
    if (!_pattern && RegExp('[、,，\n]').hasMatch(key)) {
      showToast(context, '标签名称不能包含分隔符');
      return;
    }
    if (values.isEmpty || (_pattern && values.length > 10)) {
      showToast(context, _pattern ? '请选择或填写1–10个标签' : '请至少输入一个关键词');
      return;
    }
    final rules = _pattern ? store.data.patternTagRules : store.data.tagRules;
    if (key != widget.existingKey && rules.containsKey(key)) {
      showToast(context, '这条规则已存在，请编辑已有规则');
      return;
    }
    setState(() => _saving = true);
    if (_pattern) {
      try {
        await validateLegacyPatterns([key]);
      } on FormatException catch (error) {
        if (mounted) {
          showToast(context, error.message);
          setState(() => _saving = false);
        }
        return;
      } catch (error, stack) {
        debugPrint('Tag rule validation failed: $error\n$stack');
        if (mounted) {
          showToast(context, '规则校验未完成，请重试');
          setState(() => _saving = false);
        }
        return;
      }
      if (!mounted) return;
    }
    final success = await performAction(
      context,
      () => store.update((draft) {
        final target = _pattern ? draft.patternTagRules : draft.tagRules;
        if (widget.existingKey != null) target.remove(widget.existingKey);
        target[key] = values;
        draft.recipeTags = {
          ...draft.recipeTags,
          ...(_pattern ? values : [key]),
        }.toList();
      }),
      success: '规则已保存',
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = MenuScope.of(context).data.recipeTags;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          '${widget.existingKey == null ? '添加' : '编辑'}${_pattern ? '正则' : '关键词'}规则',
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _key,
                  enabled: !_saving,
                  autofocus: true,
                  minLines: 1,
                  maxLines: _pattern ? 4 : 1,
                  decoration: InputDecoration(
                    labelText: _pattern ? '表达式' : '标签名称',
                    hintText: _pattern ? '例如：.*(牛肉|猪肉).*' : '例如：荤菜',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _values,
                  onChanged: (_) => setState(() {}),
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: _pattern ? '添加标签' : '关键词',
                    hintText: _pattern ? '例如：荤菜、家常菜' : '例如：牛肉、猪肉、鸡肉',
                    helperText: '多个内容用顿号、逗号或换行分隔',
                  ),
                ),
                if (_pattern && tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in tags)
                        FilterChip(
                          label: Text(tag),
                          selected: _split(_values.text).contains(tag),
                          onSelected: _saving
                              ? null
                              : (checked) {
                                  final selected = _split(_values.text);
                                  if (selected.contains(tag)) {
                                    selected.remove(tag);
                                  } else {
                                    if (selected.length == 10) {
                                      showToast(context, '最多添加10个标签');
                                      return;
                                    }
                                    selected.add(tag);
                                  }
                                  setState(
                                    () => _values.text = selected.join('、'),
                                  );
                                },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  _pattern
                      ? '表达式按原文保留，包括空格；菜名包含原文或正则完整匹配时生效。'
                      : '菜名包含任意一个关键词时，添加此标签。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    );
  }
}
