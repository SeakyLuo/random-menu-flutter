import '../../ui/menu_bottom_sheet.dart';
import '../../ui/tag_selection_field.dart';
import '../recipes/recipe_search.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/tag_patterns.dart';
import '../../ui/widgets.dart';
import '../../ui/menu_icon.dart';

enum TagRuleMode { literal, pattern }

Future<void> showTagRuleEditor(
  BuildContext context, {
  required TagRuleMode mode,
  String? existingKey,
}) => showMenuBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 560),
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
  bool _leaving = false;
  bool _confirmDelete = false;
  bool _confirmDiscard = false;
  late String _originalValues;
  bool get _dirty =>
      _key.text != (widget.existingKey ?? '') ||
      _values.text != _originalValues;
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
      _originalValues = _values.text;
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
      _finish();
    } else {
      setState(() => _saving = false);
    }
  }

  void _finish() {
    setState(() => _leaving = true);
    Navigator.pop(context);
  }

  void _close() {
    if (_saving) return;
    if (_confirmDelete || _confirmDiscard) {
      setState(() {
        _confirmDelete = false;
        _confirmDiscard = false;
      });
    } else if (_dirty) {
      FocusScope.of(context).unfocus();
      setState(() => _confirmDiscard = true);
    } else {
      _finish();
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    final success = await performAction(
      context,
      () => MenuScope.of(context).update((draft) {
        (_pattern ? draft.patternTagRules : draft.tagRules).remove(
          widget.existingKey,
        );
      }),
      success: '规则已删除',
    );
    if (!mounted) return;
    if (success) {
      _finish();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final confirming = _confirmDelete || _confirmDiscard;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final keywordField = TextField(
      controller: _pattern ? _key : _values,
      enabled: !_saving,
      autofocus: true,
      minLines: 1,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: '关键词',
        hintText: _pattern ? '例如：鱼' : '例如：牛肉、猪肉、鸡肉',
        helperText: _pattern ? null : '多个关键词用顿号、逗号或换行分隔',
        helperMaxLines: 2,
      ),
    );
    final data = MenuScope.of(context).data;
    final tagsField = TagSelectionField(
      label: _pattern ? '添加的标签' : '标签名称',
      selected: _pattern
          ? _split(_values.text)
          : (_key.text.isEmpty ? [] : [_key.text]),
      choices: {
        ...orderedRecipeTags(data),
        ...data.tagRules.keys,
        ...data.patternTagRules.values.expand((tags) => tags),
      }.toList(),
      busy: _saving,
      limit: _pattern ? 10 : 1,
      onChanged: (tags) => setState(() {
        if (_pattern) {
          _values.text = tags.join('、');
        } else {
          _key.text = tags.join();
        }
      }),
    );
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88 - keyboard,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _confirmDelete
                              ? '删除这条规则？'
                              : _confirmDiscard
                              ? '放弃未保存的修改？'
                              : widget.existingKey == null
                              ? '添加标签规则'
                              : '编辑标签规则',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _saving ? null : _close,
                        icon: const MenuIcon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: SingleChildScrollView(
                      child: confirming
                          ? Text(
                              _confirmDelete
                                  ? '删除“${_pattern ? widget.existingKey : _originalValues}”的自动标签规则？删除后不再使用这条规则，已有菜谱标签不受影响。'
                                  : '这次修改还没有保存。',
                              style: const TextStyle(fontSize: 16, height: 1.6),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                keywordField,
                                const SizedBox(height: 10),
                                Text(
                                  _pattern
                                      ? '菜名包含关键词或完整匹配表达式时，为未填写标签的菜谱添加以下标签。'
                                      : '菜名包含任意一个关键词时，为未填写标签的菜谱添加以下标签。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                tagsField,
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    spacing: 12,
                    children: [
                      if (confirming) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _close,
                            child: Text(_confirmDelete ? '取消' : '继续编辑'),
                          ),
                        ),
                        Expanded(
                          child: FilledButton(
                            style: _confirmDelete
                                ? FilledButton.styleFrom(
                                    backgroundColor: colors.error,
                                    foregroundColor: colors.onError,
                                  )
                                : null,
                            onPressed: _saving
                                ? null
                                : _confirmDelete
                                ? _delete
                                : _finish,
                            child: Text(
                              _confirmDelete
                                  ? (_saving ? '删除中…' : '删除规则')
                                  : '放弃修改',
                            ),
                          ),
                        ),
                      ] else ...[
                        if (widget.existingKey != null)
                          IconButton(
                            tooltip: '删除规则',
                            style: IconButton.styleFrom(
                              foregroundColor: colors.error,
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: _saving
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    setState(() => _confirmDelete = true);
                                  },
                            icon: const MenuIcon(Icons.delete_outline),
                          ),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? '保存中…' : '保存'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
