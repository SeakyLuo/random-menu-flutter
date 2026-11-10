import 'package:flutter/material.dart';
import '../core/currency.dart';
import '../core/menu_store.dart';
import 'menu_bottom_sheet.dart';
import 'menu_icon.dart';

const _commonCurrencyOrder = [
  MenuCurrency.cny,
  MenuCurrency.usd,
  MenuCurrency.eur,
  MenuCurrency.jpy,
  MenuCurrency.hkd,
  MenuCurrency.gbp,
  MenuCurrency.sgd,
  MenuCurrency.thb,
  MenuCurrency.krw,
  MenuCurrency.mop,
  MenuCurrency.twd,
  MenuCurrency.aud,
  MenuCurrency.cad,
  MenuCurrency.myr,
  MenuCurrency.vnd,
  MenuCurrency.idr,
];

Future<MenuCurrency?> selectMenuCurrency(
  BuildContext context,
  MenuCurrency selected,
) {
  final counts = <MenuCurrency, int>{};
  for (final restaurant in MenuScope.of(context).data.restaurants) {
    for (final visit in restaurant.records) {
      counts.update(visit.currency, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  final currencies = [..._commonCurrencyOrder]
    ..sort((a, b) {
      final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      return byCount != 0
          ? byCount
          : _commonCurrencyOrder
                .indexOf(a)
                .compareTo(_commonCurrencyOrder.indexOf(b));
    });
  return showMenuBottomSheet<MenuCurrency>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .65,
          maxWidth: 560,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择币种',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const MenuIcon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: currencies.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) => _CurrencyOption(
                  currency: currencies[index],
                  selected: selected == currencies[index],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({required this.currency, required this.selected});
  final MenuCurrency currency;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: .08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pop(context, currency),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currency.symbol,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: currency.label,
                      children: [
                        TextSpan(
                          text: '  ${currency.code}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(fontSize: 16, color: colors.onSurface),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 22,
                  child: selected
                      ? MenuIcon(Icons.check, size: 22, color: colors.primary)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MenuCurrencyPrefix extends StatelessWidget {
  const MenuCurrencyPrefix({super.key, required this.currency, this.onChanged});
  final MenuCurrency currency;
  final ValueChanged<MenuCurrency>? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: onChanged == null ? currency.label : '切换币种，当前${currency.label}',
    button: onChanged != null,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null
          ? null
          : () async {
              final selected = await selectMenuCurrency(context, currency);
              if (selected != null) onChanged!(selected);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currency.symbol,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
