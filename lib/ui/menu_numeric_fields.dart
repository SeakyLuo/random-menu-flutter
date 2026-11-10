import 'package:flutter/material.dart';
import 'menu_icon.dart';
import '../core/currency.dart';
import 'menu_currency_picker.dart';

class MenuPriceField extends StatelessWidget {
  const MenuPriceField({
    super.key,
    required this.controller,
    this.hintText = '填写单价',
    this.currency = MenuCurrency.cny,
    this.onCurrencyChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final MenuCurrency currency;
  final ValueChanged<MenuCurrency>? onCurrencyChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(fontSize: 15),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      hintText: hintText,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      prefixIcon: MenuCurrencyPrefix(
        currency: currency,
        onChanged: onCurrencyChanged,
      ),
    ),
  );
}

class MenuQuantityField extends StatelessWidget {
  const MenuQuantityField({
    super.key,
    required this.controller,
    this.unit = '份',
  });

  final TextEditingController controller;
  final String unit;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final count = int.tryParse(value.text) ?? 0;
          return TextField(
            controller: controller,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              prefixIcon: IconButton(
                tooltip: '减少一$unit',
                onPressed: count > 1
                    ? () => controller.text = '${count - 1}'
                    : null,
                icon: const MenuIcon(Icons.remove, size: 20),
              ),
              suffixIcon: IconButton(
                tooltip: '增加一$unit',
                onPressed: count < 100
                    ? () => controller.text = '${count + 1}'
                    : null,
                icon: const MenuIcon(Icons.add, size: 20),
              ),
            ),
          );
        },
      );
}
