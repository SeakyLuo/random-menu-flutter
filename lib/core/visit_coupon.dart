enum VisitCouponType { amount, percentage }

class VisitCoupon {
  VisitCoupon({
    this.type = VisitCouponType.amount,
    this.threshold,
    this.discount,
    this.rate,
    this.maxDiscount,
    this.quantity = 1,
  }) {
    bool positive(double value) => value.isFinite && value >= .01;
    if (threshold != null && !positive(threshold!)) {
      throw const FormatException('使用门槛必须大于 0');
    }
    if (type == VisitCouponType.amount) {
      if (discount == null ||
          !positive(discount!) ||
          rate != null ||
          maxDiscount != null) {
        throw const FormatException('请填写有效的优惠金额');
      }
    } else if (rate == null ||
        !positive(rate!) ||
        rate! >= 10 ||
        (rate! * 100 - (rate! * 100).round()).abs() > .000001 ||
        discount != null ||
        quantity != 1 ||
        (maxDiscount != null && !positive(maxDiscount!))) {
      throw const FormatException('折扣须大于 0 且小于 10，折扣券每次使用一张');
    }
    if (quantity < 1 || quantity > 100) {
      throw const FormatException('用券数量应为 1 到 100 张');
    }
  }

  final VisitCouponType type;
  final double? threshold, discount, rate, maxDiscount;
  final int quantity;

  bool appliesTo(double subtotal) =>
      threshold == null ||
      (subtotal * 100).round() >= (threshold! * 100).round();

  int reductionCents(int remaining) {
    if (!appliesTo(remaining / 100)) return 0;
    if (type == VisitCouponType.amount) {
      return ((discount! * 100).round() * quantity).clamp(0, remaining);
    }
    final rateHundredths = (rate! * 100).round();
    final payable = (remaining * rateHundredths + 500) ~/ 1000;
    final reduction = remaining - payable;
    return maxDiscount == null
        ? reduction
        : reduction.clamp(0, (maxDiscount! * 100).round());
  }

  factory VisitCoupon.fromJson(Map<String, dynamic> json) => VisitCoupon(
    type: VisitCouponType.values.byName(json['type'] as String),
    threshold: (json['threshold'] as num?)?.toDouble(),
    discount: (json['discount'] as num?)?.toDouble(),
    rate: (json['rate'] as num?)?.toDouble(),
    maxDiscount: (json['maxDiscount'] as num?)?.toDouble(),
    quantity: json['quantity'] as int,
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'threshold': threshold,
    'discount': discount,
    'rate': rate,
    'maxDiscount': maxDiscount,
    'quantity': quantity,
  };
}

class VisitCouponApplication {
  const VisitCouponApplication(
    this.beforeCents,
    this.discountCents,
    this.applied,
  );
  final int beforeCents, discountCents;
  final bool applied;
}

class VisitBill {
  VisitBill(double subtotal, List<VisitCoupon> coupons)
    : subtotalCents = (subtotal * 100).round() {
    var remaining = subtotalCents;
    for (final coupon in coupons) {
      final reduction = coupon.reductionCents(remaining);
      applications.add(
        VisitCouponApplication(
          remaining,
          reduction,
          coupon.appliesTo(remaining / 100),
        ),
      );
      remaining -= reduction;
    }
    couponCents = subtotalCents - remaining;
  }

  final int subtotalCents;
  late final int couponCents;
  final applications = <VisitCouponApplication>[];
  double get subtotal => subtotalCents / 100;
  double get discount => couponCents / 100;
  double get total => (subtotalCents - couponCents) / 100;
}
