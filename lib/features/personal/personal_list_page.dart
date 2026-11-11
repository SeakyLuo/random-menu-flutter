import '../../ui/menu_action_sheet.dart';
import '../../ui/menu_bottom_sheet.dart';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/library_widgets.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../recipes/recipe_editor.dart';

enum PersonalListKind { toCook, toEat, dislikes }

String _title(PersonalListKind kind) => switch (kind) {
  PersonalListKind.toCook => '想做',
  PersonalListKind.toEat => '想吃',
  PersonalListKind.dislikes => '不喜欢',
};
List<String> _items(MenuData data, PersonalListKind kind) => switch (kind) {
  PersonalListKind.toCook => data.toCook,
  PersonalListKind.toEat => data.toEat,
  PersonalListKind.dislikes => data.dislikes,
};

class PersonalListPage extends StatefulWidget {
  const PersonalListPage({super.key, required this.kind});
  final PersonalListKind kind;
  @override
  State<PersonalListPage> createState() => _PersonalListPageState();
}

class _PersonalListPageState extends State<PersonalListPage> {
  int _page = 0;
  String get _label => _title(widget.kind);
  Future<void> _edit([String? original, bool managing = false]) async {
    final saved = await showMenuBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      enableDrag: false,
      showDragHandle: true,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 240,
        ),
        reverseDuration: const Duration(milliseconds: 120),
      ),
      builder: (_) => _RecordEditor(
        kind: widget.kind,
        original: original,
        managing: managing,
      ),
    );
    if (saved == true && mounted) setState(() => _page = 0);
  }

  Future<void> _makeRecipe(String name) async {
    await editRecipe(context, initialName: name, wantedName: name);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(MenuScope.of(context).data, widget.kind);
    final last = items.isEmpty ? 0 : (items.length - 1) ~/ 12;
    final page = min(_page, last);
    final displayed = items.skip(page * 12).take(12).toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 48,
        title: MenuScrollTitle(
          child: MenuTitleLine(
            children: [
              Text(_label),
              const SizedBox(width: 10),
              Text(
                '${items.length} ${widget.kind == PersonalListKind.toCook ? '道' : '条'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Stack(
            children: [
              items.isEmpty
                  ? EmptyState(
                      icon: widget.kind == PersonalListKind.toCook
                          ? Icons.soup_kitchen_outlined
                          : widget.kind == PersonalListKind.toEat
                          ? Icons.storefront_outlined
                          : Icons.block,
                      title: '还没有$_label的记录',
                      message: widget.kind == PersonalListKind.dislikes
                          ? '记下不喜欢的食材和口味。'
                          : '先记下名字，留给下一次期待。',
                      actionLabel: '添加记录',
                      onAction: _edit,
                    )
                  : ListView(
                      primary: true,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                      children: [
                        for (final item in displayed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Material(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(2),
                              clipBehavior: Clip.antiAlias,
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () =>
                                            widget.kind ==
                                                PersonalListKind.toCook
                                            ? _makeRecipe(item)
                                            : _edit(item),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              height: 1.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 44,
                                      child: Tooltip(
                                        message: '管理$_label记录：$item',
                                        child: InkWell(
                                          onTap: () => _edit(item, true),
                                          splashFactory: NoSplash.splashFactory,
                                          highlightColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: .1),
                                          hoverColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: .05),
                                          child: Center(
                                            child: MenuIcon(
                                              Icons.more_horiz,
                                              size: 18,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (last > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: page == 0
                                      ? null
                                      : () => setState(() => _page = page - 1),
                                  child: const Text('上一页'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  child: Text(
                                    '${page + 1} / ${last + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: page == last
                                      ? null
                                      : () => setState(() => _page = page + 1),
                                  child: const Text('下一页'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
              if (items.isNotEmpty)
                LibraryFab(
                  label: '添加$_label记录',
                  bottom: 20,
                  size: 56,
                  onPressed: _edit,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RecordView { manage, edit, remove, discard }

class _RecordEditor extends StatefulWidget {
  const _RecordEditor({
    required this.kind,
    required this.original,
    required this.managing,
  });
  final PersonalListKind kind;
  final String? original;
  final bool managing;
  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<_RecordEditor> {
  late final _text = TextEditingController(text: widget.original ?? '')
    ..addListener(() => setState(() {}));
  late _RecordView _view = widget.managing
      ? _RecordView.manage
      : _RecordView.edit;
  final _focus = FocusNode();
  bool _saving = false;
  bool _leaving = false;
  bool get _dirty => _text.text != (widget.original ?? '');

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changeView(_RecordView view) {
    _focus.unfocus();
    setState(() => _view = view);
    if (view == _RecordView.edit) _focus.requestFocus();
  }

  void _finish([bool? saved]) {
    setState(() => _leaving = true);
    Navigator.pop(context, saved);
  }

  void _leave() {
    if (_saving) return;
    switch (_view) {
      case _RecordView.remove:
        _changeView(_RecordView.manage);
      case _RecordView.discard:
        _changeView(_RecordView.edit);
      case _RecordView.edit when _dirty:
        _changeView(_RecordView.discard);
      case _RecordView.edit:
      case _RecordView.manage:
        _finish();
    }
  }

  Future<void> _save({bool remove = false}) async {
    final value = _text.text.trim();
    final store = MenuScope.of(context);
    if (!remove) {
      if (value.isEmpty) {
        showToast(context, '请填写内容');
        return;
      }
      if (value != widget.original &&
          _items(store.data, widget.kind).contains(value)) {
        showToast(context, '这条记录已经在清单里了');
        return;
      }
    }
    setState(() => _saving = true);
    final saved = await performAction(
      context,
      () => store.update(MenuWriteScope.settings, (data) {
        final items = _items(data, widget.kind);
        items.remove(widget.original);
        if (!remove) items.insert(0, value);
      }),
      success: remove ? '已移除记录' : '清单已保存',
    );
    if (!mounted) return;
    if (saved) {
      _finish(!remove);
    } else {
      setState(() => _saving = false);
    }
  }

  String get _heading => switch (_view) {
    _RecordView.manage => widget.original!,
    _RecordView.remove => '移除这条记录？',
    _RecordView.discard => '放弃未保存的修改？',
    _RecordView.edit =>
      '${widget.original == null ? '添加' : '编辑'}${_title(widget.kind)}记录',
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height * .88 -
              MediaQuery.viewInsetsOf(context).bottom,
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
                        _heading,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _saving ? null : _leave,
                      icon: MenuIcon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _view == _RecordView.manage ? 2 : 4),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_view == _RecordView.manage) ...[
                          MenuSheetActions(
                            actions: [
                              MenuSheetAction(
                                icon: Icons.edit_outlined,
                                label: '修改名称',
                                onTap: () => _changeView(_RecordView.edit),
                              ),
                              MenuSheetAction(
                                icon: Icons.delete_outline,
                                label: '移除这条记录',
                                destructive: true,
                                onTap: () => _changeView(_RecordView.remove),
                              ),
                            ],
                          ),
                        ] else if (_view == _RecordView.edit) ...[
                          TextField(
                            controller: _text,
                            focusNode: _focus,
                            enabled: !_saving,
                            autofocus: !widget.managing,
                            maxLength: 200,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_saving) _save();
                            },
                            decoration: InputDecoration(
                              labelText:
                                  widget.kind == PersonalListKind.dislikes
                                  ? '食材或口味'
                                  : '名称',
                              hintText: widget.kind == PersonalListKind.dislikes
                                  ? '例如：香菜、太辣'
                                  : '记下菜名、餐厅或想尝试的味道',
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? '保存中…' : '保存'),
                          ),
                        ] else ...[
                          Text(
                            _view == _RecordView.remove
                                ? '“${widget.original}”会从这份清单中移除。'
                                : '这次填写的修改还没有保存。',
                            style: const TextStyle(fontSize: 16, height: 1.6),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            spacing: 12,
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving ? null : _leave,
                                  child: Text(
                                    _view == _RecordView.remove ? '保留' : '继续编辑',
                                  ),
                                ),
                              ),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _saving
                                      ? null
                                      : _view == _RecordView.remove
                                      ? () => _save(remove: true)
                                      : _finish,
                                  child: Text(
                                    _view == _RecordView.remove
                                        ? (_saving ? '移除中…' : '确认移除')
                                        : '放弃修改',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
  );
}
