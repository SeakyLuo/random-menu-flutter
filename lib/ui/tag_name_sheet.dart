import '../core/tag_path.dart';
import 'package:flutter/material.dart';
import 'menu_bottom_sheet.dart';
import 'menu_icon.dart';
import 'widgets.dart';

Future<String?> showTagNameSheet(
  BuildContext context, {
  required List<String> existing,
  bool hierarchical = false,
  String label = '标签',
}) => showMenuBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _TagNameSheet(
    existing: existing,
    hierarchical: hierarchical,
    label: label,
  ),
);

class _TagNameSheet extends StatefulWidget {
  const _TagNameSheet({
    required this.existing,
    required this.hierarchical,
    required this.label,
  });
  final List<String> existing;
  final bool hierarchical;
  final String label;

  @override
  State<_TagNameSheet> createState() => _TagNameSheetState();
}

class _TagNameSheetState extends State<_TagNameSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, '请填写${widget.label}名称');
      return;
    }
    if (RegExp('[,，、]').hasMatch(name)) {
      showToast(context, '${widget.label}名称不能包含逗号或顿号');
      return;
    }
    if (widget.hierarchical &&
        name.split('/').any((part) => part.isEmpty || part.trim() != part)) {
      showToast(context, '请填写完整的${widget.label}名称，例如：烤肉/日本烤肉');
      return;
    }
    final value = widget.hierarchical
        ? inferredTagPath(name, widget.existing)
        : name;
    if (widget.existing.contains(value)) {
      showToast(context, '该${widget.label}已存在');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '新建${widget.label}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '取消新建',
                  onPressed: () => Navigator.pop(context),
                  icon: const MenuIcon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 20,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '${widget.label}名称',
                hintText: widget.hierarchical ? '例如：日本烤肉' : '例如：下饭菜',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('创建并选中')),
          ],
        ),
      ),
    ),
  );
}
