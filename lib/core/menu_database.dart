import 'tag_path.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import 'models.dart';
import 'menu_sql_statement.dart';
import 'menu_write_scope.dart';
import 'visit_coupon_migration.dart';
import 'dish_identity_upgrade.dart';
import 'record_conflicts.dart';
import 'restaurant_tag_upgrade.dart';

part 'menu_database_sql.dart';
part 'menu_database_schema.dart';
part 'menu_database_restaurant_rows.dart';
part 'menu_database_read.dart';
part 'menu_database_write.dart';
part 'menu_database_coupon_upgrade.dart';
part 'menu_database_package_upgrade.dart';
part 'menu_database_coupon_quantity_upgrade.dart';
part 'menu_database_dish_identity_upgrade.dart';
part 'menu_database_discount_coupon_upgrade.dart';
part 'menu_database_restaurant_details.dart';
part 'menu_database_visit.dart';
part 'menu_database_restaurant_tags_upgrade.dart';

class MenuDatabase {
  MenuDatabase._(this._database);
  final Database _database;

  static Future<MenuDatabase> open(Directory directory) async {
    final database = await openDatabase(
      '${directory.path}/menu.db',
      version: 11,
      onCreate: (db, _) async {
        for (final statement in _schema) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE restaurants ADD COLUMN cover_dish_id TEXT',
          );
        }
        if (oldVersion < 2) await _upgradeVisitCoupons(db);
        if (oldVersion < 3) await _upgradeVisitPackages(db);
        if (oldVersion < 4) {
          await db.execute('DROP TABLE restaurant_dishes');
          await db.delete('images', where: 'kind = ?', whereArgs: ['dish']);
        }
        if (oldVersion < 5) await _upgradeCouponQuantities(db, oldVersion);
        if (oldVersion < 6) {
          // Offline data maintenance can classify items before the next app upgrade.
          final itemColumns = await db.rawQuery(
            'PRAGMA table_info(restaurant_visit_items)',
          );
          if (!itemColumns.any((column) => column['name'] == 'is_dish')) {
            await db.execute(
              'ALTER TABLE restaurant_visit_items ADD COLUMN is_dish '
              'INTEGER NOT NULL DEFAULT 1 CHECK (is_dish IN (0,1))',
            );
          }
          final row = (await db.query('menu_settings')).single;
          final payload =
              jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          payload['version'] = 7;
          await db.update('menu_settings', {
            'payload': jsonEncode(payload),
          }, where: 'id = 1');
        }
        if (oldVersion < 8) await _upgradeDishIdentities(db);
        if (oldVersion < 9) await _upgradeDiscountCoupons(db);
        if (oldVersion < 10) {
          await db.execute(
            "ALTER TABLE restaurant_visits ADD COLUMN currency TEXT NOT NULL DEFAULT 'CNY'",
          );
          final row = (await db.query('menu_settings')).single;
          final payload =
              jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          payload['version'] = 10;
          await db.update('menu_settings', {
            'payload': jsonEncode(payload),
          }, where: 'id = 1');
        }
        if (oldVersion < 11) await _upgradeRestaurantTags(db);
      },
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

  Future<MenuData> readForStartup() => _database.transaction((txn) async {
    final data = await _read(txn);
    if (data.selectedMenu.isEmpty &&
        data.recipes.any((recipe) => recipe.hiddenRounds > 0)) {
      await txn.update('recipes', {
        'hidden_rounds': 0,
      }, where: 'hidden_rounds > 0');
      for (final recipe in data.recipes) {
        recipe.hiddenRounds = 0;
      }
    }
    return data;
  });

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
    final snapshot = scope.visitId == null
        ? (
            data: await _read(txn, scope: scope, current: current),
            position: null,
            coverInVisit: false,
          )
        : await _readVisit(txn, current, scope);
    final data = snapshot.data;
    final previous = _tables(
      data,
      scope: scope,
      visitPosition: snapshot.position,
    );
    edit(data);
    final next = _tables(
      data,
      scope: scope,
      visitPosition: snapshot.position,
      validateVisitCover: snapshot.coverInVisit,
    );
    final batch = txn.batch();
    for (var i = 0; i < next.length; i++) {
      final before = previous[i];
      final after = next[i];
      final oldRows = {for (final row in before.rows) before.key(row): row};
      final newRows = {for (final row in after.rows) after.key(row): row};
      for (final entry in oldRows.entries) {
        if (!newRows.containsKey(entry.key)) {
          batch.delete(
            before.name,
            where: before.where,
            whereArgs: before.arguments(entry.value),
          );
        }
      }
      for (final entry in newRows.entries) {
        final row = entry.value;
        final old = oldRows[entry.key];
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

  Future<RestaurantDetailsResult> editRestaurantDetails({
    required Map<String, dynamic> before,
    required Restaurant details,
    required bool updateFavorite,
  }) => _editRestaurantDetails(
    _database,
    before: before,
    details: details,
    updateFavorite: updateFavorite,
  );
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
