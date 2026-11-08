import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_field_label.dart';
import '../../ui/widgets.dart';
import '../../ui/menu_numeric_fields.dart';
import 'visit_coupon_card.dart';

String visitCouponLabel(VisitCoupon coupon) =>
    '${coupon.threshold == null ? '' : '满 ¥${money(coupon.threshold!)} '}'
    '减 ¥${money(coupon.discount)}${coupon.quantity > 1 ? ' × ${coupon.quantity} 张' : ''}';

class VisitCouponFields extends StatelessWidget {
  const VisitCouponFields({
    super.key,
    required this.coupons,
    required this.subtotal,
    required this.autoCost,
    required this.onChanged,
  });

  final List<VisitCoupon> coupons;
  final double subtotal;
  final bool autoCost;
  final ValueChanged<List<VisitCoupon>> onChanged;

  Future<void> edit(BuildContext context, [int? index]) async {
    final coupon = await showDialog<VisitCoupon>(
      context: context,
      builder: (_) =>
          _CouponDialog(coupon: index == null ? null : coupons[index]),
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MenuFieldLabel(
        '用券',
        minHeight: 44,
        bottomSpacing: 4,
        trailing: IconButton(
          tooltip: '添加用券',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => edit(context),
          icon: const MenuIcon(Icons.add, size: 20),
        ),
      ),
      for (final (index, coupon) in coupons.indexed)
        Padding(
          padding: EdgeInsets.only(
            bottom: index == coupons.length - 1 ? 0 : 10,
          ),
          child: VisitCouponCard(
            coupon: coupon,
            notApplied: autoCost && !coupon.appliesTo(subtotal),
            onEdit: () => edit(context, index),
            onRemove: () => onChanged([...coupons]..removeAt(index)),
          ),
        ),
    ],
  );
}

class _CouponDialog extends StatefulWidget {
  const _CouponDialog({this.coupon});
  final VisitCoupon? coupon;
  @override
  State<_CouponDialog> createState() => _CouponDialogState();
}

class _CouponDialogState extends State<_CouponDialog> {
  late final threshold = TextEditingController(
    text: widget.coupon?.threshold == null
        ? ''
        : money(widget.coupon!.threshold!),
  );
  late final discount = TextEditingController(
    text: widget.coupon == null ? '' : money(widget.coupon!.discount),
  );

  late final quantity = TextEditingController(
    text: '${widget.coupon?.quantity ?? 1}',
  );

  @override
  void dispose() {
    threshold.dispose();
    discount.dispose();
    quantity.dispose();
    super.dispose();
  }

  void save() {
    final minimum = threshold.text.trim().isEmpty
        ? null
        : double.tryParse(threshold.text);
    final reduction = double.tryParse(discount.text);
    bool valid(double? value) =>
        value != null &&
        value.isFinite &&
        value >= .01 &&
        (value * 100 - (value * 100).round()).abs() < .000001;
    if (threshold.text.trim().isNotEmpty && !valid(minimum)) {
      showToast(context, '请输入有效门槛金额，最多两位小数');
      return;
    }
    if (!valid(reduction)) {
      showToast(context, '请填写减多少，金额至少 0.01 元、最多两位小数');
      return;
    }
    final count = int.tryParse(quantity.text.trim());
    if (count == null || count < 1 || count > 100) {
      showToast(context, '用券数量应为 1 到 100 张');
      return;
    }
    Navigator.pop(
      context,
      VisitCoupon(threshold: minimum, discount: reduction!, quantity: count),
    );
  }

  @override
  Widget build(BuildContext context) => MenuDialog(
    title: widget.coupon == null ? '添加用券' : '编辑用券',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MenuFieldLabel('使用门槛', hint: '选填'),
        MenuPriceField(controller: threshold, hintText: '无门槛可留空'),
        const SizedBox(height: 16),
        const MenuFieldLabel('单张减额', isRequired: true),
        MenuPriceField(controller: discount, hintText: '填写单张优惠金额'),
        const SizedBox(height: 16),
        const MenuFieldLabel('使用数量', hint: '张'),
        MenuQuantityField(controller: quantity, unit: '张'),
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
