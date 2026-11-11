import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_surface.dart';
import '../core/tag_path.dart';
import 'menu_field_label.dart';
import 'menu_tag.dart';
import 'widgets.dart';

class HierarchicalTagInput extends StatefulWidget {
  const HierarchicalTagInput({
    super.key,
    required this.selected,
    required this.choices,
    required this.onChanged,
    required this.label,
    required this.limit,
    required this.allowCreate,
    required this.busy,
    this.trailing,
    this.icon,
  });

  final List<String> selected, choices;
  final ValueChanged<List<String>> onChanged;
  final String label;
  final int limit;
  final bool allowCreate, busy;
  final Widget? trailing;
  final IconData? icon;

  @override
  State<HierarchicalTagInput> createState() => _HierarchicalTagInputState();
}

class _HierarchicalTagInputState extends State<HierarchicalTagInput>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _fieldKey = GlobalKey();
  var _direction = OptionsViewOpenDirection.down;
  double _availableHeight = 240;

  List<String> get _choices => {...widget.choices, ...widget.selected}.toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_updatePosition);
  }

  @override
  void didChangeMetrics() => _updatePosition();

  void _updatePosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focus.hasFocus) {
        setState(() {});
        return;
      }
      final box = _fieldKey.currentContext!.findRenderObject()! as RenderBox;
      final media = MediaQuery.of(context);
      final top = box.localToGlobal(Offset.zero).dy;
      final below =
          media.size.height -
          media.viewInsets.bottom -
          media.padding.bottom -
          top -
          box.size.height -
          8;
      final above = top - media.padding.top - kToolbarHeight - 8;
      final up = below < 144 && above > below;
      setState(() {
        _direction = up
            ? OptionsViewOpenDirection.up
            : OptionsViewOpenDirection.down;
        _availableHeight = math.max(0, math.min(240, up ? above : below));
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_updatePosition);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _add(String tag) {
    final remaining = widget.selected
        .where(
          (selected) =>
              !tagPathContains(selected, tag) &&
              !tagPathContains(tag, selected),
        )
        .toList();
    if (remaining.length == widget.limit) {
      showToast(context, '最多添加${widget.limit}个${widget.label}');
      return;
    }
    widget.onChanged([...remaining, tag]);
    _text.clear();
    _focus.requestFocus();
    _updatePosition();
  }

  void _submit() {
    final name = _text.text.trim();
    if (name.isEmpty) return;
    if (_choices.contains(name)) {
      _add(name);
      return;
    }
    final sameLabels = _choices
        .where((tag) => tagPathLabel(tag) == name)
        .toList();
    if (sameLabels.length == 1) {
      _add(sameLabels.single);
      return;
    }
    if (sameLabels.length > 1) {
      showToast(context, '请选择对应的${widget.label}建议');
      return;
    }
    if (!widget.allowCreate) {
      showToast(context, '请选择已有${widget.label}');
      return;
    }
    if (name.length > 20 ||
        RegExp('[,，、]').hasMatch(name) ||
        name.split('/').any((part) => part.isEmpty || part.trim() != part)) {
      showToast(context, '请填写20字以内的完整${widget.label}名称，不含逗号或顿号');
      return;
    }
    _add(inferredTagPath(name, _choices));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MenuFieldLabel(
        widget.label,
        icon: widget.icon,
        trailing: widget.trailing,
        bottomSpacing: 6,
      ),
      LayoutBuilder(
        builder: (context, constraints) => RawAutocomplete<String>(
          textEditingController: _text,
          focusNode: _focus,
          optionsViewOpenDirection: _direction,
          displayStringForOption: tagPathLabel,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty || widget.busy) return const [];
            final matches = _choices
                .where(
                  (tag) =>
                      !widget.selected.contains(tag) &&
                      tag.toLowerCase().contains(query),
                )
                .toList();
            matches.sort((a, b) {
              final aExact = tagPathLabel(a).toLowerCase() == query;
              final bExact = tagPathLabel(b).toLowerCase() == query;
              return aExact == bExact
                  ? a.compareTo(b)
                  : aExact
                  ? -1
                  : 1;
            });
            return matches;
          },
          onSelected: _add,
          fieldViewBuilder: (context, controller, focus, submit) =>
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => InputDecorator(
                  key: _fieldKey,
                  isFocused: focus.hasFocus,
                  isEmpty: widget.selected.isEmpty && value.text.isEmpty,
                  decoration: InputDecoration(
                    enabled: !widget.busy,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tag in widget.selected)
                        MenuTag(
                          tagPathLabel(tag),
                          selected: true,
                          removable: true,
                          onRemove: widget.busy
                              ? null
                              : () {
                                  widget.onChanged(
                                    widget.selected
                                        .where((item) => item != tag)
                                        .toList(),
                                  );
                                  _updatePosition();
                                },
                        ),
                      SizedBox(
                        width: math.min(constraints.maxWidth - 20, 180),
                        child: TextField(
                          controller: controller,
                          focusNode: focus,
                          enabled: !widget.busy,
                          style: const TextStyle(fontSize: 15),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onEditingComplete: () {},
                          onTapOutside: (_) => focus.unfocus(),
                          decoration: InputDecoration(
                            hintText: widget.selected.isEmpty
                                ? '输入${widget.label}'
                                : '继续输入',
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          optionsViewBuilder: (context, select, options) => Align(
            alignment: _direction == OptionsViewOpenDirection.up
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TextFieldTapRegion(
                child: GlassSurface(
                  radius: 12,
                  blurSigma: 24,
                  tintOpacity: .85,
                  child: Material(
                    type: MaterialType.transparency,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: _availableHeight,
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final tag = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              textColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                              title: Text(tagPathLabel(tag)),
                              onTap: () => select(tag),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
