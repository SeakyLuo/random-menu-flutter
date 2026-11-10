import '../../core/models.dart';
import '../../ui/widgets.dart';

String visitPackageLabel(
  VisitPackage package, {
  MenuCurrency currency = MenuCurrency.cny,
}) => '${package.name} · 套餐 ${currency.symbol}${money(package.totalPrice)}';

String restaurantFoodSummary(
  VisitDish dish, {
  VisitPackage? package,
  MenuCurrency currency = MenuCurrency.cny,
}) {
  if (dish.note.isNotEmpty) {
    return dish.note.length <= 10
        ? '“${dish.note}”'
        : '“${dish.note.substring(0, 8)}...”';
  }
  if (package != null) return visitPackageLabel(package, currency: currency);
  return dish.price == 0 ? '' : '${currency.symbol}${money(dish.price)}';
}
