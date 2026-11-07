import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_popup.dart';
import '../../ui/widgets.dart';

String visitCouponLabel(VisitCoupon coupon) =>
    '${coupon.threshold == null ? '' : '满 ¥${money(coupon.threshold!)} '}'
    '减 ¥${money(coupon.discount)}';

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
      SectionTitle(
        '用券',
        trailing: TextButton.icon(
          onPressed: () => edit(context),
          icon: const MenuIcon(Icons.add, size: 18),
          label: const Text('添加用券'),
        ),
      ),
      for (final (index, coupon) in coupons.indexed)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(visitCouponLabel(coupon)),
          subtitle: autoCost && !coupon.appliesTo(subtotal)
              ? const Text('未达门槛，本次不抵扣')
              : null,
          onTap: () => edit(context, index),
          trailing: MenuPopupButton<String>(
            tooltip: '用券操作',
            icon: const MenuIcon(Icons.more_horiz),
            onSelected: (_) => onChanged([...coupons]..removeAt(index)),
            itemBuilder: (_) => const [
              MenuPopupItem(
                value: 'remove',
                icon: Icons.delete_outline,
                destructive: true,
                child: Text('移除用券'),
              ),
            ],
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

  @override
  void dispose() {
    threshold.dispose();
    discount.dispose();
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
    Navigator.pop(
      context,
      VisitCoupon(threshold: minimum, discount: reduction!),
    );
  }

  @override
  Widget build(BuildContext context) => MenuDialog(
    title: widget.coupon == null ? '添加用券' : '编辑用券',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: threshold,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '满多少（选填）',
            prefixText: '¥ ',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: discount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => save(),
          decoration: const InputDecoration(labelText: '减多少', prefixText: '¥ '),
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
          child: MenuDialogButton(label: '保存', onPressed: save),
        ),
      ],
    ),
  );
}
