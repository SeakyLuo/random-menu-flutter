import '../../core/models.dart';
import '../../ui/widgets.dart';

String visitPackageLabel(VisitPackage package) =>
    '${package.name} · 套餐 ¥${money(package.totalPrice)}';

String restaurantFoodSummary(VisitDish dish, {VisitPackage? package}) {
  if (dish.note.isNotEmpty) {
    return dish.note.length <= 10
        ? '“${dish.note}”'
        : '“${dish.note.substring(0, 8)}...”';
  }
  if (package != null) return visitPackageLabel(package);
  return dish.price == 0 ? '' : '¥${money(dish.price)}';
}
