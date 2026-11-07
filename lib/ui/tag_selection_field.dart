import 'package:flutter/material.dart';
import 'menu_icon.dart';
import 'menu_tag.dart';
import 'tag_selection_page.dart';

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
        builder: (_) => TagSelectionPage(
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton.icon(
            onPressed: busy ? null : () => _open(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
              MenuTag(
                tag,
                removable: true,
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
