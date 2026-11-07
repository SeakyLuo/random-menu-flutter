/// Parses statement boundaries without treating quoted text/comments as SQL.
class MenuSqlStatement {
  MenuSqlStatement(String source) {
    if (source.length > 65536) {
      throw ArgumentError('SQL exceeds 65536 characters.');
    }
    final tokens = <_Token>[];
    var depth = 0;
    var i = 0;
    while (i < source.length) {
      final c = source[i];
      if (c.trim().isEmpty) {
        i++;
        continue;
      }
      if (source.startsWith('--', i)) {
        final end = source.indexOf('\n', i + 2);
        i = end < 0 ? source.length : end + 1;
        continue;
      }
      if (source.startsWith('/*', i)) {
        final end = source.indexOf('*/', i + 2);
        if (end < 0) throw const FormatException('Unterminated SQL comment.');
        i = end + 2;
        continue;
      }
      final start = i;
      if (["'", '"', '`', '['].contains(c)) {
        final close = c == '[' ? ']' : c;
        final value = StringBuffer();
        var closed = false;
        i++;
        while (i < source.length) {
          if (source[i] == close) {
            if (close != ']' &&
                i + 1 < source.length &&
                source[i + 1] == close) {
              value.write(close);
              i += 2;
              continue;
            }
            i++;
            closed = true;
            break;
          }
          value.write(source[i++]);
        }
        if (!closed) throw const FormatException('Unterminated SQL quote.');
        tokens.add(
          _Token(
            value.toString(),
            start,
            depth,
            c == "'" ? 'literal' : 'identifier',
          ),
        );
      } else if (_wordStart.hasMatch(c)) {
        i++;
        while (i < source.length && _wordPart.hasMatch(source[i])) {
          i++;
        }
        tokens.add(_Token(source.substring(start, i), start, depth, 'word'));
      } else {
        if (c == ')') depth--;
        if (depth < 0) {
          throw const FormatException('Unbalanced SQL parentheses.');
        }
        tokens.add(_Token(c, start, depth, 'symbol'));
        if (c == '(') depth++;
        i++;
      }
    }
    if (depth != 0) throw const FormatException('Unbalanced SQL parentheses.');
    final semicolons = tokens
        .where((t) => t.value == ';' && t.kind == 'symbol')
        .toList();
    if (semicolons.isNotEmpty) {
      if (semicolons.length != 1 ||
          !identical(tokens.last, semicolons.single)) {
        throw ArgumentError('Provide one SQL statement per entry.');
      }
      sql = source.substring(0, tokens.removeLast().start).trim();
    } else {
      sql = source.trim();
    }
    if (tokens.isEmpty) throw ArgumentError('SQL must not be empty.');
    var main = 0;
    if (tokens.first.keyword == 'WITH') {
      main = tokens.indexWhere(
        (t) =>
            t.depth == 0 &&
            [
              'SELECT',
              'INSERT',
              'UPDATE',
              'DELETE',
              'REPLACE',
            ].contains(t.keyword),
      );
      if (main < 0) {
        throw ArgumentError(
          'WITH must end in SELECT, INSERT, UPDATE or DELETE.',
        );
      }
    }
    operation = tokens[main].keyword;
    if (operation == 'SELECT') return;
    if (!['INSERT', 'UPDATE', 'DELETE', 'REPLACE'].contains(operation)) {
      throw ArgumentError(
        'Only SELECT and data INSERT/UPDATE/DELETE/REPLACE are supported. Schema changes, PRAGMA, ATTACH and transaction commands are not exposed.',
      );
    }
    if (tokens.any((t) => t.depth == 0 && t.keyword == 'RETURNING')) {
      throw ArgumentError(
        'RETURNING is not supported; use query_sql after committing.',
      );
    }
    var target = main + 1;
    if (target < tokens.length && tokens[target].keyword == 'OR') target += 2;
    if (target < tokens.length &&
        ['INTO', 'FROM'].contains(tokens[target].keyword)) {
      target++;
    }
    if (target >= tokens.length) throw ArgumentError('Missing write target.');
    var table = tokens[target].value;
    if (target + 1 < tokens.length && tokens[target + 1].value == '.') {
      if (table.toLowerCase() != 'main' || target + 2 >= tokens.length) {
        throw ArgumentError('Only the main database is writable.');
      }
      table = tokens[target + 2].value;
    }
    if (!tables.contains(table.toLowerCase())) {
      throw ArgumentError('Unsupported write table: $table');
    }
  }

  static const tables = [
    'recipes',
    'restaurants',
    'restaurant_addresses',
    'menu_settings',
    'favorites',
    'to_cook',
    'to_eat',
    'dislikes',
    'auto_tag_rules',
    'auto_tag_rule_values',
    'recipe_tags',
    'recipe_tag_links',
    'restaurant_dishes',
    'restaurant_visits',
    'restaurant_visit_items',
    'restaurant_visit_coupons',
    'restaurant_categories',
    'visit_companions',
    'search_history',
    'images',
  ];
  static final _wordStart = RegExp(r'[a-zA-Z_]');
  static final _wordPart = RegExp(r'[a-zA-Z_0-9$]');
  late final String sql;
  late final String operation;
  bool get readOnly => operation == 'SELECT';
}

class _Token {
  const _Token(this.value, this.start, this.depth, this.kind);
  final String value, kind;
  final int start, depth;
  String get keyword => kind == 'word' ? value.toUpperCase() : '';
}
