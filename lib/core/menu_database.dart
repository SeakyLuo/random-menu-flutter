import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'models.dart';
import 'menu_sql_statement.dart';
import 'menu_write_scope.dart';
import 'visit_coupon_migration.dart';

part 'menu_database_sql.dart';
part 'menu_database_schema.dart';
part 'menu_database_restaurant_rows.dart';
part 'menu_database_read.dart';
part 'menu_database_write.dart';
part 'menu_database_coupon_upgrade.dart';

class MenuDatabase {
  MenuDatabase._(this._database);
  final Database _database;

  static Future<MenuDatabase> open(Directory directory) async {
    final database = await openDatabase(
      '${directory.path}/menu.db',
      version: 2,
      onCreate: (db, _) async {
        for (final statement in _schema) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) => _upgradeVisitCoupons(db),
    );
    final result = MenuDatabase._(database);
    await database.transaction((txn) async {
      final settings = await txn.query('menu_settings', columns: ['id']);
      if (settings.isNotEmpty) return;
      final initial = MenuData();
      final batch = txn.batch();
      for (final table in _tables(initial)) {
        for (final row in table.rows) {
          batch.insert(table.name, row);
        }
      }
      await batch.commit(noResult: true);
    });
    return result;
  }

  Future<MenuData> read({
    MenuWriteScope scope = MenuWriteScope.all,
    MenuData? current,
  }) => _database.transaction(
    (txn) => _read(txn, scope: scope, current: current),
  );

  Future<MenuData> edit(
    MenuData current,
    MenuWriteScope scope,
    void Function(MenuData) edit,
  ) => _database.transaction((txn) async {
    final data = await _read(txn, scope: scope, current: current);
    final previous = _tables(data, scope: scope);
    edit(data);
    final next = _tables(data, scope: scope);
    final batch = txn.batch();
    for (var i = 0; i < next.length; i++) {
      final before = previous[i];
      final after = next[i];
      final oldRows = {for (final row in before.rows) before.key(row): row};
      final newRows = {for (final row in after.rows) after.key(row): row};
      for (final row in before.rows) {
        if (!newRows.containsKey(before.key(row))) {
          batch.delete(
            before.name,
            where: before.where,
            whereArgs: before.arguments(row),
          );
        }
      }
      for (final row in after.rows) {
        final old = oldRows[after.key(row)];
        if (old == null) {
          batch.insert(after.name, row);
        } else if (!_sameRow(old, row)) {
          batch.update(
            after.name,
            row,
            where: after.where,
            whereArgs: after.arguments(row),
          );
        }
      }
    }
    await batch.commit(noResult: true);
    return data;
  });
}

bool _sameRow(Map<String, Object?> before, Map<String, Object?> after) =>
    before.keys.every((key) => before[key] == after[key]);

class _TableRows {
  const _TableRows(this.name, this.primaryKey, this.rows);
  final String name;
  final List<String> primaryKey;
  final List<Map<String, Object?>> rows;
  String key(Map<String, Object?> row) => jsonEncode(arguments(row));
  String get where => primaryKey.map((key) => '$key = ?').join(' AND ');
  List<Object?> arguments(Map<String, Object?> row) => [
    for (final key in primaryKey) row[key],
  ];
}
