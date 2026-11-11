import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'search_match.dart';
import 'menu_icon.dart';

class MenuSuggestionInput extends StatefulWidget {
  const MenuSuggestionInput({
    super.key,
    required this.controller,
    required this.choices,
    required this.hintText,
    this.onSelected,
    this.autofocus = false,
    this.decoration,
    this.style,
    this.maxLines,
    this.showSuggestionsWhenEmpty = false,
    this.emptyMessage,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
    this.commaSeparated = false,
    this.adaptToAvailableSpace = false,
  });
  final TextEditingController controller;
  final List<String> choices;
  final String hintText;
  final ValueChanged<String>? onSelected;
  final bool autofocus;
  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final bool showSuggestionsWhenEmpty;
  final String? emptyMessage;
  final OptionsViewOpenDirection optionsViewOpenDirection;
  final bool commaSeparated;
  final bool adaptToAvailableSpace;

  @override
  State<MenuSuggestionInput> createState() => _MenuSuggestionInputState();
}

class _MenuSuggestionInputState extends State<MenuSuggestionInput>
    with WidgetsBindingObserver {
  final _focus = FocusNode();
  final _fieldKey = GlobalKey();
  final _layerLink = LayerLink();
  final _portal = OverlayPortalController();
  ScrollPosition? _scrollPosition;
  var _automaticDirection = OptionsViewOpenDirection.down;
  bool _directionScheduled = false;
  double _availableHeight = 240;
  OptionsViewOpenDirection get _direction => widget.adaptToAvailableSpace
      ? _automaticDirection
      : widget.optionsViewOpenDirection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_scheduleDirection);
    _focus.addListener(_updateCommaOverlay);
    widget.controller.addListener(_scheduleDirection);
    widget.controller.addListener(_updateCommaOverlay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition != position) {
      _scrollPosition?.removeListener(_scheduleDirection);
      _scrollPosition = position;
      _scrollPosition?.addListener(_scheduleDirection);
    }
    _scheduleDirection();
  }

  @override
  void didUpdateWidget(covariant MenuSuggestionInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleDirection);
      oldWidget.controller.removeListener(_updateCommaOverlay);
      widget.controller.addListener(_scheduleDirection);
      widget.controller.addListener(_updateCommaOverlay);
    }
    _scheduleDirection();
    _updateCommaOverlay();
  }

  @override
  void didChangeMetrics() => _scheduleDirection();

  void _scheduleDirection() {
    if (!widget.adaptToAvailableSpace ||
        !_focus.hasFocus ||
        _directionScheduled) {
      return;
    }
    _directionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _directionScheduled = false;
      if (!mounted || !_focus.hasFocus) return;
      final box = _fieldKey.currentContext!.findRenderObject()! as RenderBox;
      final media = MediaQuery.of(context);
      final top = box.localToGlobal(Offset.zero).dy;
      final below =
          media.size.height -
          media.viewInsets.bottom -
          media.padding.bottom -
          top -
          box.size.height;
      final above = top - media.padding.top;
      final rowHeight = media.textScaler.scale(15) * 1.4 + 28;
      final panelHeight =
          (_optionsFor(widget.controller.value).length * rowHeight + 8).clamp(
            0,
            240,
          ) +
          4;
      final next = below >= panelHeight || below >= above
          ? OptionsViewOpenDirection.down
          : OptionsViewOpenDirection.up;
      final availableHeight =
          ((next == OptionsViewOpenDirection.down ? below : above) - 4).clamp(
            0.0,
            240.0,
          );
      if (next != _automaticDirection || availableHeight != _availableHeight) {
        setState(() {
          _automaticDirection = next;
          _availableHeight = availableHeight;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.removeListener(_scheduleDirection);
    widget.controller.removeListener(_scheduleDirection);
    widget.controller.removeListener(_updateCommaOverlay);
    _focus.removeListener(_scheduleDirection);
    _focus.removeListener(_updateCommaOverlay);
    _focus.dispose();
    super.dispose();
  }

  TextRange _tokenRange(TextEditingValue value) {
    if (!widget.commaSeparated) {
      return TextRange(start: 0, end: value.text.length);
    }
    final caret = value.selection.isValid
        ? value.selection.extentOffset
        : value.text.length;
    final separator = RegExp('[,，\n]');
    final start = value.text.substring(0, caret).lastIndexOf(separator) + 1;
    final next = value.text.indexOf(separator, caret);
    return TextRange(start: start, end: next < 0 ? value.text.length : next);
  }

  String _query(TextEditingValue value) =>
      _tokenRange(value).textInside(value.text).trim();

  List<_MenuSuggestionOption> _optionsFor(TextEditingValue value) {
    final range = _tokenRange(value);
    final query = _query(value).toLowerCase();
    if (query.isEmpty && !widget.showSuggestionsWhenEmpty) {
      return const <_MenuSuggestionOption>[];
    }
    final others = widget.commaSeparated
        ? value.text
              .replaceRange(range.start, range.end, '')
              .split(RegExp('[,，\n]'))
              .map((name) => name.trim())
              .toSet()
        : const <String>{};
    final choices = widget.choices.where((name) => !others.contains(name));
    return [
          ...choices.where((name) => name.toLowerCase() == query),
          ...choices.where(
            (name) =>
                name.toLowerCase() != query &&
                name.toLowerCase().contains(query),
          ),
        ]
        .take(6)
        .map(
          (name) => _MenuSuggestionOption(
            label: name,
            replacement: value.text.replaceRange(range.start, range.end, name),
            caret: range.start + name.length,
          ),
        )
        .toList();
  }

  void _updateCommaOverlay() {
    if (!widget.commaSeparated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final show =
          _focus.hasFocus && _optionsFor(widget.controller.value).isNotEmpty;
      if (show && !_portal.isShowing) _portal.show();
      if (!show && _portal.isShowing) _portal.hide();
    });
  }

  void _selectComma(String name) {
    final value = widget.controller.value;
    final range = _tokenRange(value);
    widget.controller.value = TextEditingValue(
      text: value.text.replaceRange(range.start, range.end, name),
      selection: TextSelection.collapsed(offset: range.start + name.length),
    );
    _focus.unfocus();
    widget.onSelected?.call(name);
  }

  Widget _commaField(double width) => CompositedTransformTarget(
    link: _layerLink,
    child: OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => Positioned(
        left: 0,
        top: 0,
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: _direction == OptionsViewOpenDirection.up
              ? Alignment.topLeft
              : Alignment.bottomLeft,
          followerAnchor: _direction == OptionsViewOpenDirection.up
              ? Alignment.bottomLeft
              : Alignment.topLeft,
          child: TextFieldTapRegion(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) => _optionsView(
                context,
                width,
                _optionsFor(value),
                (option) => _selectComma(option.label),
                autocomplete: false,
              ),
            ),
          ),
        ),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => _field(value, () {}),
      ),
    ),
  );

  Widget _field(TextEditingValue value, VoidCallback submit) {
    final query = _query(value).toLowerCase();
    final noMatches =
        query.isNotEmpty &&
        !widget.choices.any((choice) => choice.toLowerCase().contains(query));
    return TextField(
      key: _fieldKey,
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      onTapOutside: (_) => _focus.unfocus(),
      style: widget.style ?? const TextStyle(fontSize: 15),
      minLines: 1,
      maxLines: widget.maxLines ?? (widget.commaSeparated ? 3 : 1),
      textInputAction: widget.onSelected == null
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: (_) {
        if (!widget.commaSeparated) submit();
        if (widget.onSelected == null) _focus.nextFocus();
      },
      decoration:
          widget.decoration ??
          InputDecoration(
            hintText: widget.hintText,
            helperText: noMatches ? widget.emptyMessage : null,
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空输入',
                    onPressed: widget.controller.clear,
                    icon: const MenuIcon(Icons.close, size: 18),
                  ),
          ),
    );
  }

  Widget _optionsView(
    BuildContext context,
    double width,
    Iterable<_MenuSuggestionOption> options,
    ValueChanged<_MenuSuggestionOption> onSelected, {
    bool autocomplete = true,
  }) {
    final query = _query(widget.controller.value);

    return Align(
      widthFactor: 1,
      heightFactor: 1,
      alignment: _direction == OptionsViewOpenDirection.up
          ? Alignment.bottomLeft
          : Alignment.topLeft,
      child: Padding(
        padding: _direction == OptionsViewOpenDirection.up
            ? const EdgeInsets.only(bottom: 4)
            : const EdgeInsets.only(top: 4),
        child: GlassSurface(
          radius: 12,
          blurSigma: 24,
          tintOpacity: .85,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: width,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      widget.commaSeparated && widget.adaptToAvailableSpace
                      ? _availableHeight
                      : 240,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    final colors = Theme.of(context).colorScheme;
                    final highlighted =
                        autocomplete &&
                        AutocompleteHighlightedOption.of(context) == index;
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: ColoredBox(
                        color: highlighted
                            ? colors.primary.withValues(alpha: .08)
                            : Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Text.rich(
                            highlightSearchText(
                              option.label,
                              query,
                              colors.primary,
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (widget.commaSeparated) return _commaField(constraints.maxWidth);
      return Autocomplete<_MenuSuggestionOption>(
        textEditingController: widget.controller,
        focusNode: _focus,
        optionsViewOpenDirection: _direction,
        displayStringForOption: (option) => option.replacement,
        optionsBuilder: _optionsFor,
        fieldViewBuilder: (context, controller, focus, submit) =>
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => _field(value, submit),
            ),
        onSelected: (value) {
          widget.controller.selection = TextSelection.collapsed(
            offset: value.caret,
          );
          _focus.unfocus();
          widget.onSelected?.call(value.label);
        },
        optionsViewBuilder: (context, onSelected, options) =>
            _optionsView(context, constraints.maxWidth, options, onSelected),
      );
    },
  );
}

class _MenuSuggestionOption {
  const _MenuSuggestionOption({
    required this.label,
    required this.replacement,
    required this.caret,
  });
  final String label;
  final String replacement;
  final int caret;
}
