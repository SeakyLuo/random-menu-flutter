import 'package:flutter/material.dart';
import 'menu_bottom_sheet.dart';
import 'menu_icon.dart';
import 'widgets.dart';

Future<String?> showTagNameSheet(
  BuildContext context, {
  required List<String> existing,
}) => showMenuBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _TagNameSheet(existing: existing),
);

class _TagNameSheet extends StatefulWidget {
  const _TagNameSheet({required this.existing});
  final List<String> existing;

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
      showToast(context, '请填写标签名称');
      return;
    }
    if (RegExp('[,，、]').hasMatch(name)) {
      showToast(context, '标签名称不能包含逗号或顿号');
      return;
    }
    if (widget.existing.contains(name)) {
      showToast(context, '该标签已存在');
      return;
    }
    Navigator.pop(context, name);
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
                const Expanded(
                  child: Text(
                    '新建标签',
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
              decoration: const InputDecoration(
                labelText: '标签名称',
                hintText: '例如：下饭菜',
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
