import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../core/models.dart';
import 'legacy_reader.dart';
import 'legacy_restaurants.dart';

class LegacyImportResult {
  LegacyImportResult({
    required this.data,
    required this.photos,
    required this.summary,
  });
  final MenuData data;
  final Map<String, Uint8List> photos;
  final String summary;
}

LegacyImportResult parseLegacyArchive(Archive archive) {
  final files = LegacyFiles(archive);
  final raw = files.json('RandomMenuSettings.json');
  if (raw is! Map<String, dynamic>) {
    throw const FormatException('备份中的旧版设置格式不正确，未恢复任何数据。');
  }
  final current =
      files.entries.containsKey('selfFoods.json') &&
      files.entries.containsKey('restaurants.json') &&
      files.entries.containsKey('autoTagMap.json');
  final old =
      raw.containsKey('Foods') &&
      raw.containsKey('Tags') &&
      raw.containsKey('MyFavorites');
  if (current == old) {
    throw const FormatException('备份版本无法明确识别，请使用原应用导出的完整备份。');
  }
  final reader = _LegacyMenu(files);
  final data = current ? reader.current(raw) : reader.early(raw);
  data.legacyImagePaths = files.imagePaths;
  data.legacyMetadata = {
    'format': current ? 'android-room-export' : 'android-early-settings',
    'source': reader.originals,
    'imageNames': files.imageNames,
  };
  final recordCount = data.restaurants.fold(
    0,
    (count, restaurant) => count + restaurant.records.length,
  );
  return LegacyImportResult(
    data: data,
    photos: files.photos,
    summary:
        '${current ? 'Android 版' : '早期 Android 版'}备份：${data.recipes.length} 道菜谱、'
        '${data.restaurants.length} 家餐厅、$recordCount 次用餐记录、${files.photos.length} 张照片，'
        '${data.recipeDraft == null ? '无' : '含一份'}菜谱草稿。'
        '原标签、标签规则、清单、随手记及可用搜索历史会一并恢复；未引用照片也完整保留。',
  );
}

class _LegacyMenu {
  _LegacyMenu(this.files);
  final LegacyFiles files;
  final originals = <String, dynamic>{};

  MenuData current(Map<String, dynamic> raw) {
    final settings = LegacyObject(raw, {
      'ToCook',
      'ToEat',
      'DislikeFood',
      'FoodDraft',
      'Note',
      'AutoTag',
    });
    const names = {
      'RandomMenuSettings.json',
      'selfFoods.json',
      'restaurants.json',
      'autoTagMap.json',
    };
    files.collectImages(names);
    originals['RandomMenuSettings.json'] = raw;
    for (final name in names.where(
      (name) => name != 'RandomMenuSettings.json',
    )) {
      originals[name] = files.json(name);
      if (originals[name] is! List) settings.fail();
    }
    final recipes = (originals['selfFoods.json'] as List)
        .map((raw) => recipe(raw))
        .toList();
    _unique(recipes.map((recipe) => recipe.id));
    final restaurants = parseLegacyRestaurants(
      originals['restaurants.json'] as List,
      files,
    );
    _unique(restaurants.map((restaurant) => restaurant.id));
    final rules = <String, List<String>>{};
    final catalog = <String>{...recipes.expand((recipe) => recipe.tags)};
    for (final rawRule in originals['autoTagMap.json'] as List) {
      final rule = LegacyObject(rawRule, {'id', 'keyword', 'tags'});
      rule.integer('id');
      final keyword = rule.text('keyword', required: true);
      final tags = rule.list('tags').map((tag) => _tag(tag, false)).toList();
      rules[keyword] = {...?rules[keyword], ...tags}.toList();
      catalog.addAll(tags);
    }
    final draft = settings.has('FoodDraft')
        ? recipe(settings.values['FoodDraft'], draft: true)
        : null;
    if (draft != null) catalog.addAll(draft.tags);
    return MenuData(
      recipes: recipes,
      restaurants: restaurants,
      toCook: legacyStrings(settings.list('ToCook')),
      toEat: legacyStrings(settings.list('ToEat')),
      dislikes: legacyStrings(settings.list('DislikeFood')),
      note: settings.text('Note'),
      autoTag: settings.flag('AutoTag'),
      recipeDraft: draft,
      recipeDraftSourceId:
          draft != null && recipes.any((recipe) => recipe.id == draft.id)
          ? draft.id
          : null,
      recipeTags: catalog.toList(),
      patternTagRules: rules,
    );
  }

  MenuData early(Map<String, dynamic> raw) {
    final settings = LegacyObject(raw, {
      'DislikeFood',
      'Foods',
      'MyFavorites',
      'Note',
      'SearchHistory',
      'Tags',
      'ToCook',
      'ToEat',
    });
    files.collectImages({'RandomMenuSettings.json'});
    originals['RandomMenuSettings.json'] = raw;
    var index = 0;
    final recipes = settings
        .wrappedList('Foods')
        .map((raw) => recipe(raw, early: true, earlyIndex: index++))
        .toList();
    final favorites = legacyStrings(
      settings.wrappedList('MyFavorites'),
    ).toSet();
    final names = recipes.map((recipe) => recipe.name).toSet();
    if (favorites.any((name) => !names.contains(name))) {
      throw const FormatException('备份的收藏关联不完整，未恢复任何数据。');
    }
    for (final recipe in recipes) {
      recipe.favorite = recipe.favorite || favorites.contains(recipe.name);
    }
    final tags = settings
        .wrappedList('Tags')
        .map((raw) => _tag(raw, true))
        .toList();
    return MenuData(
      recipes: recipes,
      toCook: legacyStrings(settings.wrappedList('ToCook')),
      toEat: legacyStrings(settings.wrappedList('ToEat')),
      dislikes: legacyStrings(settings.wrappedList('DislikeFood')),
      note: settings.text('Note'),
      recipeTags: {
        ...tags,
        ...recipes.expand((recipe) => recipe.tags),
      }.toList(),
      recipeSearchHistory: legacyStrings(settings.wrappedList('SearchHistory')),
    );
  }

  Recipe recipe(
    Object? raw, {
    bool early = false,
    bool draft = false,
    int earlyIndex = 0,
  }) {
    final food = LegacyObject(
      raw,
      early
          ? {
              'Cover',
              'DateAdded',
              'HideCount',
              'Images',
              'IsFavorite',
              'Name',
              'Note',
              'Tags',
            }
          : {
              'id',
              'name',
              'images',
              'tags',
              'note',
              'favorite',
              'cover',
              'dateAdded',
              'hideCount',
            },
    );
    String key(String lower, String upper) => early ? upper : lower;
    final id = early
        ? earlyIndex
        : food.integer('id', omitted: draft ? 0 : null);
    if (!early && !draft && id <= 0) food.fail();
    final name = food.text(key('name', 'Name'), required: !draft);
    final images = early ? food.wrappedList('Images') : food.list('images');
    final tags = early ? food.wrappedList('Tags') : food.list('tags');
    final hidden = food.integer(key('hideCount', 'HideCount'));
    if (hidden < 0) food.fail();
    return Recipe(
      id: 'android-recipe-$id',
      name: name,
      note: food.text(key('note', 'Note')),
      favorite: food.flag(key('favorite', 'IsFavorite')),
      hiddenRounds: hidden,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        food.integer(key('dateAdded', 'DateAdded')),
      ),
      tags: tags.map((tag) => _tag(tag, early)).toList(),
      imagePaths: files.images(
        legacyStrings(images),
        cover: food.text(key('cover', 'Cover')),
      ),
    );
  }

  String _tag(Object? raw, bool early) {
    final tag = LegacyObject(
      raw,
      early ? {'Counter', 'Name'} : {'id', 'name', 'counter'},
    );
    tag.integer(early ? 'Counter' : 'counter');
    if (!early) tag.integer('id');
    return tag.text(early ? 'Name' : 'name', required: true);
  }

  void _unique(Iterable<String> ids) {
    final all = ids.toList();
    if (all.toSet().length != all.length) {
      throw const FormatException('备份存在重复的数据关联，未恢复任何数据。');
    }
  }
}
