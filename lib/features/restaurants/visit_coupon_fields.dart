import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_field_label.dart';
import '../../ui/widgets.dart';
import 'visit_coupon_card.dart';
import 'visit_coupon_editor.dart';

String visitCouponLabel(
  VisitCoupon coupon, {
  MenuCurrency currency = MenuCurrency.cny,
}) =>
    '${coupon.threshold == null ? '' : '满 ${currency.symbol}${money(coupon.threshold!)} '}'
    '${coupon.type == VisitCouponType.percentage ? '${coupon.rate} 折' : '减 ${currency.symbol}${money(coupon.discount!)}'}'
    '${coupon.maxDiscount == null ? '' : '，最多优惠 ${currency.symbol}${money(coupon.maxDiscount!)}'}'
    '${coupon.quantity > 1 ? ' × ${coupon.quantity} 张' : ''}';

class VisitCouponSliver extends StatelessWidget {
  const VisitCouponSliver({
    super.key,
    required this.coupons,
    this.currency = MenuCurrency.cny,
    this.onCurrencyChanged,
    required this.subtotal,
    required this.autoCost,
    required this.onChanged,
  });

  final List<VisitCoupon> coupons;
  final MenuCurrency currency;
  final ValueChanged<MenuCurrency>? onCurrencyChanged;
  final double subtotal;
  final bool autoCost;
  final ValueChanged<List<VisitCoupon>> onChanged;

  Future<void> edit(BuildContext context, [int? index]) async {
    final coupon = await showVisitCouponEditor(
      context,
      coupon: index == null ? null : coupons[index],
      currency: currency,
      onCurrencyChanged: onCurrencyChanged,
    );
    if (coupon == null) return;
    final updated = [...coupons];
    if (index == null) {
      updated.add(coupon);
    } else {
      updated[index] = coupon;
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final bill = VisitBill(subtotal, coupons);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MenuFieldLabel(
                '用券',
                minHeight: 44,
                bottomSpacing: 4,
                trailing: IconButton(
                  tooltip: '添加用券',
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => edit(context),
                  icon: const MenuIcon(Icons.add, size: 20),
                ),
              ),
              if (coupons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '从上到下依次抵扣，拖动右侧手柄排序',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SliverReorderableList(
          itemCount: coupons.length,
          onReorderItem: (from, to) {
            final updated = [...coupons];
            updated.insert(to, updated.removeAt(from));
            onChanged(updated);
          },
          proxyDecorator: (child, index, animation) => child,
          itemBuilder: (context, index) {
            final coupon = coupons[index];
            final application = bill.applications[index];
            return Padding(
              key: ObjectKey(coupon),
              padding: const EdgeInsets.only(bottom: 10),
              child: VisitCouponCard(
                coupon: coupon,
                currency: currency,
                notApplied: autoCost && !application.applied,
                savedAmount: autoCost ? application.discountCents / 100 : null,
                reorderIndex: index,
                onEdit: () => edit(context, index),
                onRemove: () => onChanged([...coupons]..removeAt(index)),
              ),
            );
          },
        ),
      ],
    );
  }
}
