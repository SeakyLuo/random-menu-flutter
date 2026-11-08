import 'package:flutter/material.dart';
import '../../ui/widgets.dart';

class RestaurantPrice extends StatelessWidget {
  const RestaurantPrice(this.value, {super.key, this.showUnit = true});

  final double value;
  final bool showUnit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        text: '¥${money(value)}',
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
