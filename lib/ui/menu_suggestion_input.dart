import 'package:flutter/material.dart';
import 'search_match.dart';
import 'menu_icon.dart';

class MenuSuggestionInput extends StatefulWidget {
  const MenuSuggestionInput({
    super.key,
    required this.controller,
    required this.choices,
    required this.hintText,
    this.onSelected,
    this.showSuggestionsWhenEmpty = false,
    this.emptyMessage,
  });
  final TextEditingController controller;
  final List<String> choices;
  final String hintText;
  final ValueChanged<String>? onSelected;
  final bool showSuggestionsWhenEmpty;
  final String? emptyMessage;

  @override
  State<MenuSuggestionInput> createState() => _MenuSuggestionInputState();
}

class _MenuSuggestionInputState extends State<MenuSuggestionInput> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Autocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty && !widget.showSuggestionsWhenEmpty)
          return const Iterable<String>.empty();
        return [
          ...widget.choices.where((name) => name.toLowerCase() == query),
          ...widget.choices.where(
            (name) =>
                name.toLowerCase() != query &&
                name.toLowerCase().contains(query),
          ),
        ].take(6);
      },
      fieldViewBuilder: (context, controller, focus, submit) =>
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final query = value.text.trim().toLowerCase();
              final noMatches =
                  query.isNotEmpty &&
                  !widget.choices.any(
                    (choice) => choice.toLowerCase().contains(query),
                  );
              return TextField(
                controller: controller,
                focusNode: focus,
                style: const TextStyle(fontSize: 15),
                textInputAction: widget.onSelected == null
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) {
                  submit();
                  if (widget.onSelected == null) focus.nextFocus();
                },
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  helperText: noMatches ? widget.emptyMessage : null,
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空输入',
                          onPressed: controller.clear,
                          icon: const MenuIcon(Icons.close, size: 18),
                        ),
                ),
              );
            },
          ),
      onSelected: (value) {
        _focus.unfocus();
        widget.onSelected?.call(value);
      },
      optionsViewBuilder: (context, onSelected, options) {
        final query = widget.controller.text.trim();

        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: constraints.maxWidth,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      final colors = Theme.of(context).colorScheme;
                      final highlighted =
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
                                option,
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
        );
      },
    ),
  );
}
