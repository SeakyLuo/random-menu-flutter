import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class MenuStore extends ChangeNotifier {
  MenuStore._(this.directory, this._data, this._snapshot);
  final Directory directory;
  MenuData _data;
  String _snapshot;
  MenuData get data => _data;
  Future<void> _pending = Future.value();

  static Future<MenuStore> open() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/random_menu');
    await directory.create(recursive: true);
    final file = File('${directory.path}/menu.json');
    final snapshot = await file.exists()
        ? await file.readAsString()
        : jsonEncode(MenuData().toJson());
    final data = MenuData.fromJson(
      jsonDecode(snapshot) as Map<String, dynamic>,
    );
    return MenuStore._(directory, data, snapshot);
  }

  // Serialize edits and publish only after the complete snapshot is on disk.
  Future<void> update(
    void Function(MenuData draft) edit, {
    Future<void>? publishAfter,
  }) {
    final result = _pending.then((_) async {
      final draft = await _copyMenu(_snapshot);
      edit(draft);
      final temporary = File('${directory.path}/menu.json.tmp');
      final snapshot = await _prepareMenu(draft, temporary.path);
      if (publishAfter != null) await publishAfter;
      await temporary.rename('${directory.path}/menu.json');
      _data = draft;
      _snapshot = snapshot;
      notifyListeners();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> replace(MenuData source) => update((draft) {
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
    draft.recipeSearchHistory = source.recipeSearchHistory;
    draft.restaurantSearchHistory = source.restaurantSearchHistory;
    draft.recipeTagSort = source.recipeTagSort;
    draft.patternTagRules = source.patternTagRules;
    draft.legacyMetadata = source.legacyMetadata;
  });

  Future<String> keepImage(String source) async {
    final images = Directory('${directory.path}/images');
    await images.create(recursive: true);
    final extension = source.split('.').last.toLowerCase();
    final destination = '${images.path}/${newId()}.$extension';
    await File(source).copy(destination);
    return destination;
  }
}

Future<MenuData> _copyMenu(String snapshot) => Isolate.run(
  () => MenuData.fromJson(jsonDecode(snapshot) as Map<String, dynamic>),
);

Future<String> _prepareMenu(MenuData data, String path) =>
    Isolate.run(() async {
      final snapshot = jsonEncode(data.toJson());
      await File(path).writeAsString(snapshot, flush: true);
      return snapshot;
    });

class MenuScope extends InheritedNotifier<MenuStore> {
  const MenuScope({super.key, required MenuStore store, required super.child})
    : super(notifier: store);
  static MenuStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MenuScope>()!.notifier!;
}
