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
  bool get dirty =>
      jsonEncode(records.map((v) => v.toJson()).toList()) !=
      jsonEncode(original.map((v) => v.toJson()).toList());

  bool changed(Visit visit) {
    final before = original
        .where((record) => record.id == visit.id)
        .firstOrNull;
    return before == null ||
        jsonEncode(before.toJson()) != jsonEncode(visit.toJson());
  }

  Future<List<Visit>> prepare(MenuStore store) async {
    final retained = <String, Future<String>>{};
    Future<String> keep(String path) => retained.putIfAbsent(
      path,
      () async => path.startsWith('${store.directory.path}/images/')
          ? path
          : store.keepImage(path),
    );
    final prepared = <Visit>[];
    for (final source in records) {
      final visit = Visit.fromJson(source.toJson());
      visit.imagePaths = await Future.wait(visit.imagePaths.map(keep));
      for (final dish in visit.items) {
        dish.imagePaths = await Future.wait(dish.imagePaths.map(keep));
      }
      prepared.add(visit);
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
