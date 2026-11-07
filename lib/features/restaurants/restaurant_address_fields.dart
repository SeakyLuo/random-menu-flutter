import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';

bool validateRestaurantAddresses(
  BuildContext context,
  List<RestaurantAddress> addresses,
) {
  final seen = <String>{};
  for (final address in addresses) {
    if (address.detail.trim().isEmpty) {
      showToast(context, '请填写分店的详细地址');
      return false;
    }
    if (!seen.add(address.fullAddress)) {
      showToast(context, '分店地址重复，请修改或移除');
      return false;
    }
  }
  return true;
}

class RestaurantAddressFields extends StatefulWidget {
  const RestaurantAddressFields({
    super.key,
    required this.address,
    required this.onChanged,
    this.autofocus = false,
    this.trailing,
  });
  final RestaurantAddress address;
  final ValueChanged<RestaurantAddress> onChanged;
  final bool autofocus;
  final Widget? trailing;

  @override
  State<RestaurantAddressFields> createState() =>
      _RestaurantAddressFieldsState();
}

class _RestaurantAddressFieldsState extends State<RestaurantAddressFields> {
  late final _province = TextEditingController(text: widget.address.province);
  late final _city = TextEditingController(text: widget.address.city);
  late final _county = TextEditingController(text: widget.address.county);
  late final _detail = TextEditingController(text: widget.address.detail);
  late bool _regionOpen =
      widget.address.province.isEmpty &&
      widget.address.city.isEmpty &&
      widget.address.county.isEmpty;

  void _changed(String _) => widget.onChanged(
    RestaurantAddress(
      id: widget.address.id,
      province: _province.text.trim(),
      city: _city.text.trim(),
      county: _county.text.trim(),
      detail: _detail.text.trim(),
    ),
  );

  @override
  void didUpdateWidget(covariant RestaurantAddressFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final pair in [
      (_province, widget.address.province),
      (_city, widget.address.city),
      (_county, widget.address.county),
      (_detail, widget.address.detail),
    ]) {
      if (pair.$1.text.trim() != pair.$2) pair.$1.text = pair.$2;
    }
  }

  @override
  void dispose() {
    for (final controller in [_province, _city, _county, _detail]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = [
      widget.address.province,
      if (widget.address.city != widget.address.province) widget.address.city,
      widget.address.county,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                region.isEmpty ? '省市区' : region,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: _regionOpen ? '收起省市区' : '修改省市区',
              onPressed: () => setState(() => _regionOpen = !_regionOpen),
              icon: MenuIcon(
                _regionOpen ? Icons.check : Icons.edit_outlined,
                size: 18,
              ),
            ),
            ?widget.trailing,
          ],
        ),
        if (_regionOpen) ...[
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in [
                  (_province, '省 / 直辖市'),
                  (_city, '城市'),
                  (_county, '区 / 县'),
                ])
                  SizedBox(
                    width: constraints.maxWidth >= 360
                        ? (constraints.maxWidth - 16) / 3
                        : (constraints.maxWidth - 8) / 2,
                    child: TextField(
                      controller: field.$1,
                      onChanged: _changed,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(hintText: field.$2),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _detail,
          autofocus: widget.autofocus,
          onChanged: _changed,
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(fontSize: 15, height: 1.5),
          decoration: const InputDecoration(hintText: '街道、门牌号或商场楼层'),
        ),
      ],
    );
  }
}
