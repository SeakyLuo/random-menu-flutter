import '../../core/menu_sql_statement.dart';
import '../../core/menu_store.dart';

class MenuMcpSqlTools {
  MenuMcpSqlTools(this.store);
  final MenuStore store;
  static const names = ['inspect_database', 'query_sql', 'execute_sql'];
  static const _parameters = {
    'type': 'array',
    'items': {
      'type': ['string', 'number', 'null'],
    },
    'maxItems': 200,
    'description':
        'Positional ? parameters. JSON boolean values must be expressed in SQL as json(?) with text true/false, not SQLite integers.',
  };
  static const _statement = {
    'type': 'object',
    'properties': {
      'sql': {'type': 'string'},
      'parameters': _parameters,
    },
    'required': ['sql', 'parameters'],
    'additionalProperties': false,
  };
  static List<Map<String, Object?>> get definitions => [
    for (final name in names)
      {
        'name': name,
        'title': switch (name) {
          'inspect_database' => '查看数据库结构',
          'query_sql' => 'SQL 查询',
          _ => 'SQL 修改数据',
        },
        'description': switch (name) {
          'inspect_database' =>
            'Read SQLite table definitions, JSON payload field shapes and relationship rules before using SQL. SQL is a fallback; prefer existing recipe/restaurant/visit CRUD tools.',
          'query_sql' =>
            'Execute one read-only SELECT (including WITH) on a separate read-only connection. Use SQL only when existing tools cannot express the requested query. Read inspect_database first. Always select only needed columns, ORDER BY for stable pagination. Up to 200 rows/1 MiB; blob values are returned as {base64:...}.',
          _ =>
            'Fallback only: execute user-requested data INSERT/UPDATE/DELETE/REPLACE statements as ONE transaction, maximum 20 statements. Prioritize existing CRUD tools. Read actual payloads before editing; preserve images/IDs/unmodified fields and maintain branch/menu/visit references. Use scalar column updates for entities; json_set is for menu_settings.payload only. Validate effect with query_sql. Schema changes, PRAGMA, ATTACH, transaction control and RETURNING are not supported. Database execution errors roll back all statements. A connection loss/timeout does NOT prove rollback: query state before deciding next actions, never retry blindly. SQL bypasses business rules and does not delete photo files. Each call requires user authorization of its SQL and parameters.',
        },
        'annotations': {
          'readOnlyHint': name != 'execute_sql',
          'destructiveHint': name == 'execute_sql',
          'openWorldHint': false,
        },
        'inputSchema': {
          'type': 'object',
          'properties': {
            if (name == 'query_sql') ...{
              'sql': {'type': 'string'},
              'parameters': _parameters,
              'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
              'offset': {'type': 'integer', 'minimum': 0},
            },
            if (name == 'execute_sql') ...{
              'statements': {
                'type': 'array',
                'items': _statement,
                'minItems': 1,
                'maxItems': 20,
              },
            },
          },
          'required': switch (name) {
            'query_sql' => ['sql', 'parameters', 'limit', 'offset'],
            'execute_sql' => ['statements'],
            _ => <String>[],
          },
          'additionalProperties': false,
        },
      },
  ];

  Future<Map<String, Object?>> call(String name, Map<String, dynamic> args) {
    switch (name) {
      case 'inspect_database':
        return store.inspectSqlDatabase();
      case 'query_sql':
        return store.querySql(
          MenuSqlStatement(args['sql'] as String),
          _params(args['parameters'] as List),
          args['limit'] as int,
          args['offset'] as int,
        );
      case 'execute_sql':
        final statements = args['statements'] as List;
        if (statements.isEmpty) {
          throw ArgumentError('Provide at least one SQL write.');
        }
        return store.executeSql([
          for (final entry in statements)
            (
              statement: MenuSqlStatement(entry['sql'] as String),
              parameters: _params(entry['parameters'] as List),
            ),
        ]);
      default:
        throw ArgumentError('Unknown SQL tool: $name');
    }
  }

  static List<Object?> _params(List values) {
    for (final value in values) {
      if (value != null && value is! String && value is! num) {
        throw ArgumentError('SQL parameters must be strings, numbers or null.');
      }
      if (value is num && !value.isFinite) {
        throw ArgumentError('SQL numbers must be finite.');
      }
    }
    return List<Object?>.from(values);
  }
}
