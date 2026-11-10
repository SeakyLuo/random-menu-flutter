import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'restaurant_address_fields.dart';

Future<RestaurantAddress?> editRestaurantAddress(
  BuildContext context, {
  RestaurantAddress? address,
}) => Navigator.push<RestaurantAddress>(
  context,
  MaterialPageRoute(builder: (_) => _AddressEditor(address: address)),
);

class _AddressEditor extends StatefulWidget {
  const _AddressEditor({this.address});
  final RestaurantAddress? address;
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  late RestaurantAddress address = widget.address == null
      ? RestaurantAddress(id: newId())
      : RestaurantAddress.fromJson(widget.address!.toJson());
  bool leaving = false;
  bool get dirty =>
      address.province != (widget.address?.province ?? '') ||
      address.city != (widget.address?.city ?? '') ||
      address.county != (widget.address?.county ?? '') ||
      address.detail != (widget.address?.detail ?? '');

  Future<void> leave() async {
    if (dirty &&
        !await confirmAction(
          context,
          title: '放弃地址修改？',
          message: '还未保存的地址修改将丢失。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context);
  }

  void save() {
    if (address.detail.isEmpty) {
      showToast(context, '请填写详细地址');
      return;
    }
    if (!dirty) address.location = widget.address?.location;
    setState(() => leaving = true);
    Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || !dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: MenuScrollTitle(
          child: Text(widget.address == null ? '添加地址' : '编辑地址'),
        ),
        leading: IconButton(
          tooltip: '返回',
          onPressed: leave,
          icon: const MenuIcon(Icons.arrow_back),
        ),
        actions: [TextButton(onPressed: save, child: const Text('完成'))],
      ),
      body: ListView(
        primary: true,
        padding: const EdgeInsets.all(24),
        children: [
          RestaurantAddressFields(
            address: address,
            autofocus: widget.address != null,
            onChanged: (value) => setState(() => address = value),
          ),
        ],
      ),
    ),
  );
}
