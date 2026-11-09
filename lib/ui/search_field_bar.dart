import 'package:flutter/material.dart';
import 'glass_surface.dart';
import 'menu_icon.dart';

class SearchFieldBar extends StatelessWidget {
  const SearchFieldBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.hintText,
    required this.onClose,
  });

  final String hintText;
  final VoidCallback onClose;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  static double clearance(BuildContext context) =>
      88 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 1.4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final field = GlassSurface(
      radius: 24,
      shadowOpacity: .4,
      borderColor: dark ? const Color(0x24ffffff) : const Color(0xe6ffffff),
      gradientColors: dark
          ? const [Color(0xf51c2b24), Color(0xeb1a2822)]
          : const [Color(0xf5ffffff), Color(0xebf7faf8)],
      child: Material(
        type: MaterialType.transparency,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            style: const TextStyle(fontSize: 16, height: 1.4),
            textAlignVertical: TextAlignVertical.center,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            onTapOutside: (_) => focusNode.unfocus(),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: scheme.onSurfaceVariant),
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                maxWidth: 40,
                minHeight: 48,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: MenuIcon(
                    Icons.search,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索',
                      onPressed: () {
                        controller.clear();
                        focusNode.requestFocus();
                      },
                      icon: const MenuIcon(Icons.close, size: 18),
                    ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        GlassSurface(
          radius: 24,
          shadowOpacity: .4,
          borderColor: dark ? const Color(0x24ffffff) : const Color(0xe6ffffff),
          gradientColors: dark
              ? const [Color(0xf51c2b24), Color(0xeb1a2822)]
              : const [Color(0xf5ffffff), Color(0xebf7faf8)],
          child: SizedBox.square(
            dimension: 48,
            child: IconButton(
              tooltip: '关闭搜索',
              onPressed: onClose,
              icon: MenuIcon(Icons.close, size: 22, color: scheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}
