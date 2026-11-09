import 'package:uuid/uuid.dart';

List<String> upgradedDishIds(List<String> ids) {
  final counts = <String, int>{};
  for (final id in ids) {
    counts.update(id, (count) => count + 1, ifAbsent: () => 1);
  }
  return [
    for (final id in ids)
      if (id.isEmpty || counts[id]! > 1) const Uuid().v4() else id,
  ];
}
