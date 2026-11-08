import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'restaurant_filter_pickers.dart';

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
      showToast(context, '地址重复，请修改或移除');
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
  late final _detail = TextEditingController(text: widget.address.detail);

  void _selectRegion() => showRestaurantRegionWheel(
    context,
    level: 3,
    province: widget.address.province,
    city: widget.address.city,
    county: widget.address.county,
    onConfirm: (province, city, county) {
      if (!mounted) return;
      final address = widget.address;
      if (province == address.province &&
          city == address.city &&
          county == address.county) {
        return;
      }
      widget.onChanged(
        RestaurantAddress(
          id: address.id,
          province: province,
          city: city,
          county: county,
          detail: address.detail,
        ),
      );
    },
  );

  void _changed(String value) {
    final address = widget.address;
    final detail = value.trim();
    if (detail == address.detail) return;
    widget.onChanged(
      RestaurantAddress(
        id: address.id,
        province: address.province,
        city: address.city,
        county: address.county,
        detail: detail,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant RestaurantAddressFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_detail.text.trim() != widget.address.detail) {
      _detail.text = widget.address.detail;
    }
  }

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = [
      widget.address.province,
      if (widget.address.city != widget.address.province) widget.address.city,
      widget.address.county,
    ].where((s) => s.isNotEmpty).join(' · ');
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      color: theme.inputDecorationTheme.fillColor,
      shape: theme.brightness == Brightness.dark
          ? theme.inputDecorationTheme.enabledBorder
          : theme.inputDecorationTheme.border,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectRegion,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        heightFactor: 1,
                        child: Text(
                          region.isEmpty ? '选择省市区' : region,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ?widget.trailing,
            ],
          ),
          TextField(
            controller: _detail,
            autofocus: widget.autofocus,
            onChanged: _changed,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(fontSize: 15, height: 1.5),
            decoration: const InputDecoration(
              hintText: '街道、门牌号或商场楼层',
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 14),
            ),
          ),
        ],
      ),
    );
  }
}
