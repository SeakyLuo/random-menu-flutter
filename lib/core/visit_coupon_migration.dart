import 'visit_coupon.dart';

/// Extract only explicit, already-used monetary offers. Future offers, points,
/// percentage discounts and unspecified coupons stay in the original note.
({String note, List<VisitCoupon> coupons}) extractVisitCoupons(String note) {
  if (RegExp('忘买|还有.*张.*券|下次|可以买|可以用|每\\d+减').hasMatch(note)) {
    return (note: note, coupons: []);
  }
  final coupons = <VisitCoupon>[];
  const amount = r'(\d+(?:\.\d+)?)';
  final voucher = RegExp(
    '(?:(?:美团|大众点评)(?:上)?)?(?:买了?)?(?:(\\d+)张)?满?'
    '$amount(?:抵扣?|买了)$amount(?:的?券)?(?:买了(\\d+)张)?',
  );
  var remaining = note.replaceAllMapped(voucher, (match) {
    final paid = double.parse(match[2]!);
    final face = double.parse(match[3]!);
    if (face <= paid) return match[0]!;
    final count = int.parse(match[1] ?? match[4] ?? '1');
    coupons.addAll(
      List.generate(
        count,
        (_) => VisitCoupon(
          threshold: face,
          discount: ((face - paid) * 100).round() / 100,
        ),
      ),
    );
    return '';
  });
  remaining = remaining.replaceAllMapped(
    RegExp('(?:然后)?(?:(?:美团|招商银行))?满$amount减$amount|^$amount减$amount\$'),
    (match) {
      coupons.add(
        VisitCoupon(
          threshold: double.parse(match[1] ?? match[3]!),
          discount: double.parse(match[2] ?? match[4]!),
        ),
      );
      return '';
    },
  );
  remaining = remaining.replaceAllMapped(
    RegExp('(?:美团(?:买单)?(?:又|还)?减了?|用券(?:扣了?|减了?|-)|券抵|商家代金券)$amount(?:元)?'),
    (match) {
      coupons.add(VisitCoupon(discount: double.parse(match[1]!)));
      return '';
    },
  );
  // The source records explicitly name two coupons with a combined ¥30 saving.
  remaining = remaining.replaceAllMapped(RegExp('美团两张券减了30'), (_) {
    coupons.add(VisitCoupon(discount: 30));
    return '';
  });
  if (coupons.isEmpty) return (note: note, coupons: coupons);
  remaining = remaining
      .replaceAll(RegExp(r'^[，,。；;\s]+|[，,。；;\s]+$'), '')
      .replaceAll(RegExp(r'[，,]{2,}'), '，');
  return (note: remaining, coupons: coupons);
}
