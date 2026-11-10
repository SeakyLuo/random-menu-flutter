import 'dart:convert';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../core/record_conflicts.dart';

class RestaurantVisitDraft {
  const RestaurantVisitDraft(this.visit, this.addresses);
  final Visit visit;
  final List<RestaurantAddress> addresses;
}

class RestaurantRecordDraft {
  RestaurantRecordDraft(List<Visit> source)
    : original = source.map((visit) => Visit.fromJson(visit.toJson())).toList(),
      records = source.map((visit) => Visit.fromJson(visit.toJson())).toList();
  final List<Visit> original;
  final List<Visit> records;
  late final _originalJson = {
    for (final visit in original) visit.id: jsonEncode(visit.toJson()),
  };
  bool get dirty =>
      records.length != original.length ||
      records.indexed.any(
        (entry) => entry.$2.id != original[entry.$1].id || changed(entry.$2),
      );

  bool changed(Visit visit) =>
      _originalJson[visit.id] != jsonEncode(visit.toJson());

  Future<List<Visit>> prepare(MenuStore store) async {
    final prepared = [
      for (final visit in records)
        if (changed(visit)) Visit.fromJson(visit.toJson()),
    ];
    final existing = {
      for (final visit in original) ...[
        ...visit.imagePaths,
        for (final dish in visit.items) ...dish.imagePaths,
      ],
    };
    final imagesDirectory = '${store.directory.path}/images/';
    final added =
        {
              for (final visit in prepared) ...[
                ...visit.imagePaths,
                for (final dish in visit.items) ...dish.imagePaths,
              ],
            }
            .where(
              (path) =>
                  !existing.contains(path) && !path.startsWith(imagesDirectory),
            )
            .toList();
    final retained = <String, String>{};
    for (var offset = 0; offset < added.length; offset += 8) {
      final batch = added.skip(offset).take(8).toList();
      final saved = await Future.wait(batch.map(store.keepImage));
      for (var i = 0; i < batch.length; i++) {
        retained[batch[i]] = saved[i];
      }
    }
    if (retained.isNotEmpty) {
      for (final visit in prepared) {
        visit.imagePaths = [
          for (final path in visit.imagePaths) retained[path] ?? path,
        ];
        for (final dish in visit.items) {
          dish.imagePaths = [
            for (final path in dish.imagePaths) retained[path] ?? path,
          ];
        }
      }
    }
    return prepared;
  }

  List<Visit> merge(List<Visit> current, List<Visit> prepared) {
    final result = [...current];
    final local = {for (final visit in records) visit.id: visit};
    final saved = {for (final visit in prepared) visit.id: visit};
    final latest = {for (final visit in current) visit.id: visit};
    final originalIds = original.map((visit) => visit.id).toSet();
    for (final before in original) {
      final after = local[before.id];
      if (after != null &&
          jsonEncode(before.toJson()) == jsonEncode(after.toJson())) {
        continue;
      }
      requireUnchangedRecord(before.toJson(), latest[before.id]?.toJson());
      final index = result.indexWhere((visit) => visit.id == before.id);
      if (after == null) {
        result.removeAt(index);
      } else {
        result[index] = saved[before.id]!;
      }
    }
    result.addAll(prepared.where((visit) => !originalIds.contains(visit.id)));
    return result;
  }
}
