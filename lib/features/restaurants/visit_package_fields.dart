import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/widgets.dart';

Future<VisitPackage?> showVisitPackageEditor(
  BuildContext context, {
  VisitPackage? package,
}) => showDialog<VisitPackage>(
  context: context,
  builder: (_) => _PackageDialog(package: package),
);

class _PackageDialog extends StatefulWidget {
  const _PackageDialog({this.package});
  final VisitPackage? package;
  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  late final name = TextEditingController(text: widget.package?.name ?? '');
  late final price = TextEditingController(
    text: widget.package == null ? '' : money(widget.package!.totalPrice),
  );

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty) {
      showToast(context, '请填写套餐名称');
      return;
    }
    final value = double.tryParse(price.text.trim());
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        (value * 100 - (value * 100).round()).abs() > .000001) {
      showToast(context, '请填写有效的套餐总价，最多两位小数');
      return;
    }
    Navigator.pop(
      context,
      VisitPackage(
        id: widget.package?.id ?? newId(),
        name: name.text.trim(),
        totalPrice: value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MenuDialog(
    title: widget.package == null ? '添加套餐' : '编辑套餐',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: '套餐名称'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: price,
          textInputAction: TextInputAction.done,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => save(),
          decoration: const InputDecoration(
            labelText: '套餐总价',
            prefixText: '¥ ',
          ),
        ),
      ],
    ),
    actions: Row(
      children: [
        Expanded(
          child: MenuDialogButton(
            label: '取消',
            role: MenuDialogRole.secondary,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MenuDialogButton(label: '保存', onPressed: save),
        ),
      ],
    ),
  );
}
