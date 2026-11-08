class VisitCoupon {
  VisitCoupon({this.threshold, required this.discount, this.quantity = 1}) {
    if (!discount.isFinite ||
        discount < .01 ||
        (threshold != null && (!threshold!.isFinite || threshold! < .01))) {
      throw const FormatException('用券金额必须大于 0');
    }
    if (quantity < 1 || quantity > 100) {
      throw const FormatException('用券数量应为 1 到 100 张');
    }
  }

  final double? threshold;
  final double discount;
  final int quantity;

  bool appliesTo(double subtotal) =>
      threshold == null ||
      (subtotal * 100).round() >= (threshold! * 100).round();

  factory VisitCoupon.fromJson(Map<String, dynamic> json) => VisitCoupon(
    threshold: (json['threshold'] as num?)?.toDouble(),
    discount: (json['discount'] as num).toDouble(),
    quantity: json['quantity'] as int,
  );

  Map<String, dynamic> toJson() => {
    'threshold': threshold,
    'discount': discount,
    'quantity': quantity,
  };
}

class VisitBill {
  VisitBill(double subtotal, List<VisitCoupon> coupons)
    : subtotalCents = (subtotal * 100).round(),
      couponCents = coupons
          .where((coupon) => coupon.appliesTo(subtotal))
          .fold(
            0,
            (sum, coupon) =>
                sum + (coupon.discount * 100).round() * coupon.quantity,
          );

  final int subtotalCents;
  final int couponCents;
  double get subtotal => subtotalCents / 100;
  double get discount => couponCents.clamp(0, subtotalCents) / 100;
  double get total =>
      (subtotalCents - couponCents.clamp(0, subtotalCents)) / 100;
}
