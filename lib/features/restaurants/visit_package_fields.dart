import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/menu_currency_picker.dart';
import '../../ui/widgets.dart';

Future<VisitPackage?> showVisitPackageEditor(
  BuildContext context, {
  VisitPackage? package,
  MenuCurrency currency = MenuCurrency.cny,
  ValueChanged<MenuCurrency>? onCurrencyChanged,
  Future<bool> Function(VisitPackage package, MenuCurrency currency)? onSave,
}) => showDialog<VisitPackage>(
  context: context,
  builder: (_) => _PackageDialog(
    package: package,
    currency: currency,
    onCurrencyChanged: onCurrencyChanged,
    onSave: onSave,
  ),
);

class _PackageDialog extends StatefulWidget {
  const _PackageDialog({
    this.package,
    required this.currency,
    this.onCurrencyChanged,
    this.onSave,
  });
  final VisitPackage? package;
  final MenuCurrency currency;
  final ValueChanged<MenuCurrency>? onCurrencyChanged;
  final Future<bool> Function(VisitPackage package, MenuCurrency currency)?
  onSave;
  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  late MenuCurrency currency = widget.currency;
  bool saving = false;
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

  Future<void> save() async {
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
    final package = VisitPackage(
      id: widget.package?.id ?? newId(),
      name: name.text.trim(),
      totalPrice: value,
    );
    if (widget.onSave != null) {
      FocusScope.of(context).unfocus();
      setState(() => saving = true);
      final success = await widget.onSave!(package, currency);
      if (!mounted) return;
      if (!success) {
        setState(() => saving = false);
        return;
      }
    }
    if (!mounted) return;
    widget.onCurrencyChanged?.call(currency);
    Navigator.pop(context, package);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AbsorbPointer(
      absorbing: saving,
      child: MenuDialog(
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => save(),
              decoration: InputDecoration(
                labelText: '套餐总价',
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                prefixIcon: MenuCurrencyPrefix(
                  currency: currency,
                  onChanged: widget.onCurrencyChanged == null
                      ? null
                      : (value) => setState(() => currency = value),
                ),
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
              child: MenuDialogButton(
                label: saving ? '保存中…' : '保存',
                busy: saving,
                onPressed: save,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
