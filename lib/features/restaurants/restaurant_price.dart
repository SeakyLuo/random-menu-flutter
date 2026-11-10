import 'package:flutter/material.dart';
import '../../ui/widgets.dart';
import '../../core/models.dart';

class RestaurantPrice extends StatelessWidget {
  const RestaurantPrice(
    this.value, {
    super.key,
    this.showUnit = true,
    this.currency = MenuCurrency.cny,
  });

  final double value;
  final MenuCurrency currency;
  final bool showUnit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        text: '${currency.symbol}${money(value)}',
        children: [
          if (showUnit)
            TextSpan(
              text: ' /人',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.onSurface,
      ),
    );
  }
}

class RestaurantPrices extends StatelessWidget {
  const RestaurantPrices(this.restaurant, {super.key});
  final Restaurant restaurant;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final price in restaurant.averageCosts.entries)
        RestaurantPrice(price.value, currency: price.key),
    ],
  );
}
