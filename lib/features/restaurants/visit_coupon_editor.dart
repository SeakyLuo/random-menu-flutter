import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_bottom_sheet.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_field_label.dart';
import '../../ui/menu_numeric_fields.dart';
import '../../ui/widgets.dart';

Future<VisitCoupon?> showVisitCouponEditor(
  BuildContext context, {
  VisitCoupon? coupon,
  MenuCurrency currency = MenuCurrency.cny,
  ValueChanged<MenuCurrency>? onCurrencyChanged,
}) => showMenuBottomSheet<VisitCoupon>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: BoxConstraints(
    maxWidth: 560,
    maxHeight: MediaQuery.sizeOf(context).height * .88,
  ),
  builder: (_) => _CouponSheet(
    coupon: coupon,
    currency: currency,
    onCurrencyChanged: onCurrencyChanged,
  ),
);

class _CouponSheet extends StatefulWidget {
  const _CouponSheet({
    this.coupon,
    required this.currency,
    this.onCurrencyChanged,
  });
  final VisitCoupon? coupon;
  final MenuCurrency currency;
  final ValueChanged<MenuCurrency>? onCurrencyChanged;
  @override
  State<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<_CouponSheet> {
  late MenuCurrency currency = widget.currency;
  late VisitCouponType type = widget.coupon?.type ?? VisitCouponType.amount;
  late final threshold = TextEditingController(
    text: widget.coupon?.threshold?.toString() ?? '',
  );
  late final discount = TextEditingController(
    text: widget.coupon?.discount?.toString() ?? '',
  );
  late final rate = TextEditingController(
    text: widget.coupon?.rate?.toString() ?? '',
  );
  late final maximum = TextEditingController(
    text: widget.coupon?.maxDiscount?.toString() ?? '',
  );
  late final quantity = TextEditingController(
    text: '${widget.coupon?.quantity ?? 1}',
  );

  @override
  void dispose() {
    for (final controller in [threshold, discount, rate, maximum, quantity]) {
      controller.dispose();
    }
    super.dispose();
  }

  void save() {
    bool valid(double? value) =>
        value != null &&
        value.isFinite &&
        value >= .01 &&
        (value * 100 - (value * 100).round()).abs() < .000001;
    final minimum = threshold.text.trim().isEmpty
        ? null
        : double.tryParse(threshold.text);
    if (threshold.text.trim().isNotEmpty && !valid(minimum)) {
      showToast(context, '请输入有效门槛金额，最多两位小数');
      return;
    }
    final reduction = double.tryParse(discount.text);
    final count = int.tryParse(quantity.text);
    final percentage = double.tryParse(rate.text);
    final cap = maximum.text.trim().isEmpty
        ? null
        : double.tryParse(maximum.text);
    if (type == VisitCouponType.amount) {
      if (!valid(reduction)) {
        showToast(context, '请填写有效的单张优惠金额，最多两位小数');
        return;
      }
      if (count == null || count < 1 || count > 100) {
        showToast(context, '用券数量应为 1 到 100 张');
        return;
      }
    } else {
      if (!valid(percentage) || percentage! >= 10) {
        showToast(context, '请输入大于 0、小于 10 的折扣，最多两位小数');
        return;
      }
      if (maximum.text.trim().isNotEmpty && !valid(cap)) {
        showToast(context, '请输入有效优惠上限，最多两位小数');
        return;
      }
    }
    widget.onCurrencyChanged?.call(currency);
    Navigator.pop(
      context,
      VisitCoupon(
        type: type,
        threshold: minimum,
        discount: type == VisitCouponType.amount ? reduction : null,
        rate: type == VisitCouponType.percentage ? percentage : null,
        maxDiscount: type == VisitCouponType.percentage ? cap : null,
        quantity: type == VisitCouponType.amount ? count! : 1,
      ),
    );
  }

  void changeType(VisitCouponType value) {
    if (value == type) return;
    FocusScope.of(context).unfocus();
    setState(() => type = value);
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            widget.coupon == null ? '添加用券' : '编辑用券',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: '关闭',
          onPressed: () => Navigator.pop(context),
          icon: const MenuIcon(Icons.close),
        ),
      ],
    ),
  );

  Widget _fields() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<VisitCouponType>(
          groupValue: type,
          onChanged: (value) => changeType(value!),
          child: Wrap(
            spacing: 20,
            runSpacing: 4,
            children: [
              for (final option in VisitCouponType.values)
                MergeSemantics(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => changeType(option),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<VisitCouponType>(
                            value: option,
                            activeColor: Theme.of(context).colorScheme.primary,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          Text(
                            option == VisitCouponType.amount ? '满减券' : '折扣券',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const MenuFieldLabel('使用门槛'),
        MenuPriceField(
          currency: currency,
          onCurrencyChanged: widget.onCurrencyChanged == null
              ? null
              : (value) => setState(() => currency = value),
          controller: threshold,
          hintText: '无门槛可留空',
        ),
        const SizedBox(height: 16),
        if (type == VisitCouponType.amount) ...[
          const MenuFieldLabel('单张减额', isRequired: true),
          MenuPriceField(
            currency: currency,
            onCurrencyChanged: widget.onCurrencyChanged == null
                ? null
                : (value) => setState(() => currency = value),
            controller: discount,
            hintText: '填写单张优惠金额',
          ),
          const SizedBox(height: 16),
          const MenuFieldLabel('使用数量'),
          MenuQuantityField(controller: quantity, unit: '张'),
        ] else ...[
          const MenuFieldLabel('折扣', isRequired: true),
          TextField(
            controller: rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: '例如：8.8',
              suffixText: '折',
            ),
          ),
          const SizedBox(height: 16),
          const MenuFieldLabel('最高优惠'),
          MenuPriceField(
            currency: currency,
            onCurrencyChanged: widget.onCurrencyChanged == null
                ? null
                : (value) => setState(() => currency = value),
            controller: maximum,
            hintText: '不封顶可留空',
          ),
        ],
      ],
    ),
  );

  Widget _saveButton() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: save,
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('保存'),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Short landscape viewports need the header and save button to scroll too.
          final short =
              constraints.maxHeight <
              240 * MediaQuery.textScalerOf(context).scale(14) / 14;
          if (short) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [_header(), _fields(), _saveButton()],
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              Flexible(child: SingleChildScrollView(child: _fields())),
              _saveButton(),
            ],
          );
        },
      ),
    ),
  );
}
