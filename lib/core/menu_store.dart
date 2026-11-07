import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'menu_database.dart';
import 'menu_write_scope.dart';
export 'menu_write_scope.dart';
import 'menu_sql_statement.dart';
import 'photo_storage.dart';

class MenuStore extends ChangeNotifier {
  MenuStore._(this.directory, this._database, this._data, this.photos);
  final PhotoStorage photos;
  final MenuDatabase _database;
  final Directory directory;
  MenuData _data;
  MenuData get data => _data;
  Future<void> _pending = Future.value();

  static Future<MenuStore> open() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/random_menu');
    await directory.create(recursive: true);
    final database = await MenuDatabase.open(directory);
    final data = await database.read();
    final photos = await PhotoStorage.open(directory);
    return MenuStore._(directory, database, data, photos);
  }

  Future<void> reload({MenuWriteScope scope = MenuWriteScope.all}) {
    final result = _pending.then((_) async {
      final data = await _database.read(scope: scope, current: _data);
      _data = data;
      notifyListeners();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  // Serialize edits and publish only after the complete snapshot is on disk.
  Future<void> update(
    MenuWriteScope scope,
    void Function(MenuData draft) edit, {
    Future<void>? publishAfter,
  }) {
    final result = _pending.then((_) async {
      final draft = await _database.edit(_data, scope, edit);
      if (publishAfter != null) await publishAfter;
      _data = draft;
      notifyListeners();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> replace(MenuData source) => update(MenuWriteScope.all, (draft) {
    draft.recipePositions = {};
    draft.restaurantPositions = {};
    draft.recipeTagIds = {};
    draft.restaurantCategoryIds = {};
    draft.recipes = source.recipes;
    draft.restaurants = source.restaurants;
    draft.toCook = source.toCook;
    draft.toEat = source.toEat;
    draft.dislikes = source.dislikes;
    draft.note = source.note;
    draft.themeMode = source.themeMode;
    draft.autoTag = source.autoTag;
    draft.tagRules = source.tagRules;
    draft.selectedMenu = source.selectedMenu;
    draft.recipeDraft = source.recipeDraft;
    draft.recipeDraftSourceId = source.recipeDraftSourceId;
    draft.legacyImagePaths = source.legacyImagePaths;
    draft.recipeTags = source.recipeTags;
    draft.restaurantCategories = source.restaurantCategories;
    draft.recipeSearchHistory = source.recipeSearchHistory;
    draft.restaurantSearchHistory = source.restaurantSearchHistory;
    draft.recipeTagSort = source.recipeTagSort;
    draft.patternTagRules = source.patternTagRules;
  });

  Future<Map<String, Object?>> inspectSqlDatabase() =>
      _scheduleSql(_database.inspectSql);

  Future<Map<String, Object?>> querySql(
    MenuSqlStatement statement,
    List<Object?> parameters,
    int limit,
    int offset,
  ) => _scheduleSql(
    () => _database.querySql(statement, parameters, limit, offset),
  );

  Future<Map<String, Object?>> executeSql(
    List<({MenuSqlStatement statement, List<Object?> parameters})> statements,
  ) => _scheduleSql(() async {
    final saved = await _database.executeSql(statements);
    _data = saved.data;
    notifyListeners();
    return saved.result;
  });

  Future<T> _scheduleSql<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    // Continue the queue; the original future still delivers errors to MCP.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<String> keepImage(String source) async {
    return photos.keep(source);
  }
}

class MenuScope extends InheritedNotifier<MenuStore> {
  const MenuScope({super.key, required MenuStore store, required super.child})
    : super(notifier: store);
  static MenuStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MenuScope>()!.notifier!;
}
