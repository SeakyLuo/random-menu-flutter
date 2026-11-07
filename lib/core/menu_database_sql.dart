part of 'menu_database.dart';

extension MenuDatabaseSql on MenuDatabase {
  Future<Map<String, Object?>> inspectSql() => _database.transaction((
    txn,
  ) async {
    final schema = await txn.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name IN (${List.filled(MenuSqlStatement.tables.length, '?').join(', ')}) ORDER BY name",
      MenuSqlStatement.tables,
    );
    return {
      'tables': schema,
      'payloadFields': {'menu_settings': _settings(MenuData())},
      'notes': [
        'Prefer existing CRUD tools. SQL is a fallback for user-requested operations they cannot express.',
        'payloadFields are shape examples, not existing records. Read actual rows before changing them.',
        'recipes/restaurants use scalar columns; they have no payload. position controls display order. Preserve id and position during updates.',
        'restaurant_dishes, restaurant_visits and restaurant_visit_items are authoritative. Visits/items reference their restaurant, and items reference their visit. dish_id can be empty for manually entered dishes; keep historical item snapshots when a catalog dish changes or is deleted.',
        'restaurant_addresses is authoritative for branches. restaurant_id references restaurants.id; visits reference branches using address_id. Keep these associations consistent.',
        'Use json_extract/json_set/json_each for JSON; do not replace a complete payload with a partial object. Booleans inside JSON must remain JSON true/false.',
        'menu_settings must retain its single row id=1. On recipe deletion update its selectedMenu and recipeDraftSourceId as needed.',
        'favorites is authoritative for recipe/restaurant favorites, one target per row; do not store favorite in entity payloads. Remove favorites when deleting their target.',
        'to_cook, to_eat and dislikes store one name per row, ordered by position. These are free-text names, not recipe/restaurant IDs.',
        'auto_tag_rules stores ordered literal (rule_key=tag) and pattern (rule_key=expression) rules. auto_tag_rule_values stores ordered keywords for literal rules and tags for pattern rules. Keep mode/rule_key associations consistent.',
        'menu_settings.payload contains ordinary settings and transient menu/draft state only. Collections and automatic tag rules live in their own tables. Historical import archives are not retained.',
        'recipe_tags and restaurant_categories use stable id/name pairs. recipe_tag_links.tag_id and restaurants.category_id reference those identities. Rename the catalog name without rewriting associations. listed controls whether unused entries appear in the managed catalog.',
        'images stores ordered paths for recipe/dish/visit/item/draft/legacy owners. item owners use owner_id=visit ID and item_position=visit item position. Other owners use item_position=-1. restaurant_id is empty for recipe/draft/legacy. Remove or reorder image associations together with their owner.',
        'visit_companions stores ordered names per visit. search_history stores keyword/position per recipe or restaurant search. restaurants.addresses and restaurant_visits.dishes retain legacy string arrays as JSON; auto_cost is 0 or 1.',
        'SQL does not apply CRUD business rules or delete image files. Maintain tags, totals, references and other business fields yourself.',
        'Only data DML is exposed. No schema changes or PRAGMA/ATTACH. Parameters use positional ? placeholders.',
        'All statements in execute_sql commit together or roll back together.',
      ],
    };
  });

  Future<Map<String, Object?>> querySql(
    MenuSqlStatement statement,
    List<Object?> parameters,
    int limit,
    int offset,
  ) async {
    if (!statement.readOnly) {
      throw ArgumentError('query_sql accepts SELECT only.');
    }
    final readOnly = await openDatabase(
      _database.path,
      readOnly: true,
      singleInstance: false,
    );
    try {
      return await readOnly.transaction((txn) async {
        final rows = await txn.rawQuery(
          'SELECT * FROM (\n${statement.sql}\n) LIMIT ${limit + 1} OFFSET $offset',
          parameters,
        );
        final result = <String, Object?>{
          'rows': [
            for (final row in rows.take(limit))
              {
                for (final entry in row.entries)
                  entry.key: entry.value is List<int>
                      ? {'base64': base64Encode(entry.value as List<int>)}
                      : entry.value,
              },
          ],
          'hasMore': rows.length > limit,
          'nextOffset': rows.length > limit ? offset + limit : null,
        };
        if (utf8.encode(jsonEncode(result)).length > 1024 * 1024) {
          throw StateError(
            'SQL result exceeds 1 MiB. Select fewer columns or reduce limit.',
          );
        }
        return result;
      });
    } finally {
      await readOnly.close();
    }
  }

  Future<({MenuData data, Map<String, Object?> result})> executeSql(
    List<({MenuSqlStatement statement, List<Object?> parameters})> statements,
  ) => _database.transaction((txn) async {
    final affected = <int>[];
    // At most 20 statements, supplied explicitly as one atomic business request.
    for (final entry in statements) {
      if (entry.statement.readOnly) {
        throw ArgumentError('execute_sql accepts data writes only.');
      }
      affected.add(await txn.rawUpdate(entry.statement.sql, entry.parameters));
    }
    final data = await _read(txn);
    final invalid = await Future.wait([
      txn.rawQuery(
        'SELECT id FROM restaurant_addresses WHERE NOT EXISTS (SELECT 1 FROM restaurants WHERE restaurants.id = restaurant_addresses.restaurant_id) LIMIT 1',
      ),
      for (final table in ['restaurant_dishes', 'restaurant_visits'])
        txn.rawQuery(
          'SELECT id FROM $table WHERE NOT EXISTS (SELECT 1 FROM restaurants WHERE restaurants.id = $table.restaurant_id) LIMIT 1',
        ),
      txn.rawQuery(
        'SELECT recipe_id FROM recipe_tag_links WHERE NOT EXISTS (SELECT 1 FROM recipes WHERE recipes.id = recipe_tag_links.recipe_id) LIMIT 1',
      ),
      txn.rawQuery(
        'SELECT visit_id FROM restaurant_visit_items WHERE NOT EXISTS (SELECT 1 FROM restaurant_visits WHERE restaurant_visits.restaurant_id = restaurant_visit_items.restaurant_id AND restaurant_visits.id = restaurant_visit_items.visit_id) LIMIT 1',
      ),
      txn.rawQuery(
        'SELECT rule_key FROM auto_tag_rule_values WHERE NOT EXISTS (SELECT 1 FROM auto_tag_rules WHERE auto_tag_rules.mode = auto_tag_rule_values.mode AND auto_tag_rules.rule_key = auto_tag_rule_values.rule_key) LIMIT 1',
      ),
      for (final target in {
        'recipe': 'recipes',
        'restaurant': 'restaurants',
      }.entries)
        txn.rawQuery(
          'SELECT target_id FROM favorites WHERE target_type = ? AND NOT EXISTS (SELECT 1 FROM ${target.value} WHERE ${target.value}.id = favorites.target_id) LIMIT 1',
          [target.key],
        ),
      txn.rawQuery(
        'SELECT tag_id FROM recipe_tag_links WHERE NOT EXISTS (SELECT 1 FROM recipe_tags WHERE recipe_tags.id = recipe_tag_links.tag_id) LIMIT 1',
      ),
      txn.rawQuery(
        'SELECT category_id FROM restaurants WHERE category_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM restaurant_categories WHERE restaurant_categories.id = restaurants.category_id) LIMIT 1',
      ),
      txn.rawQuery(
        'SELECT visit_id FROM visit_companions WHERE NOT EXISTS (SELECT 1 FROM restaurant_visits WHERE restaurant_visits.restaurant_id = visit_companions.restaurant_id AND restaurant_visits.id = visit_companions.visit_id) LIMIT 1',
      ),
    ]);
    if (invalid.any((rows) => rows.isNotEmpty)) {
      throw StateError(
        'SQL would leave orphan collection/restaurant/tag records. Entire transaction rolled back.',
      );
    }
    return (
      data: data,
      result: {
        'committed': true,
        'affectedRows': affected,
        'totalAffectedRows': affected.fold(0, (sum, count) => sum + count),
      },
    );
  });
}
