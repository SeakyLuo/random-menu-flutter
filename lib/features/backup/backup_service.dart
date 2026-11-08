import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../core/tag_patterns.dart';
import '../../core/photo_storage.dart';
import 'legacy_import.dart';

Iterable<List<String>> _imageLists(MenuData data) sync* {
  yield data.legacyImagePaths;
  if (data.recipeDraft != null) yield data.recipeDraft!.imagePaths;
  for (final recipe in data.recipes) {
    yield recipe.imagePaths;
  }
  for (final restaurant in data.restaurants) {
    for (final visit in restaurant.records) {
      yield visit.imagePaths;
      for (final item in visit.items) {
        yield item.imagePaths;
      }
    }
  }
}

class PreparedBackup {
  PreparedBackup(
    this.data,
    this.photos, {
    this.summary = '本应用完整备份',
    this.sources = const {},
  });
  final String summary;
  final MenuData data;
  final Map<String, Uint8List> photos;
  final Map<String, Uint8List> sources;
}

class BackupService {
  static Future<Uint8List> export(MenuData source) async {
    final data = MenuData.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );
    final photos = <String, Uint8List>{};
    final sources = <String, Uint8List>{};
    final paths = <String, String>{};
    for (final list in _imageLists(data)) {
      for (var i = 0; i < list.length; i++) {
        final original = list[i];
        if (!paths.containsKey(original)) {
          final name = 'photos/${newId()}.${original.split('.').last}';
          photos[name] = await File(original).readAsBytes();
          final source = PhotoStorage.sourceFile(original);
          if (await source.exists()) sources[name] = await source.readAsBytes();
          paths[original] = name;
        }
        list[i] = paths[original]!;
      }
    }
    final json = jsonEncode(data.toJson());
    return Isolate.run(() {
      final archive = Archive()..addFile(ArchiveFile.string('menu.json', json));
      for (final entry in photos.entries) {
        archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
      }
      for (final entry in sources.entries) {
        archive.addFile(
          ArchiveFile.bytes('${entry.key}.source.json', entry.value),
        );
      }
      return ZipEncoder().encodeBytes(archive);
    });
  }

  static Future<PreparedBackup> read(Uint8List bytes) async {
    final backup = await Isolate.run(() {
      final archive = ZipDecoder().decodeBytes(
        bytes,
        verify: true,
        throwOnError: true,
      );
      final manifest = archive.findFile('menu.json');
      if (manifest == null) {
        final legacy = parseLegacyArchive(archive);
        return PreparedBackup(
          legacy.data,
          legacy.photos,
          summary: legacy.summary,
        );
      }
      final data = MenuData.fromJson(
        jsonDecode(utf8.decode(manifest.content)) as Map<String, dynamic>,
      );
      if (archive.findFile('RandomMenuSettings.json') != null) {
        throw const FormatException('备份混有不同版本的内容，无法明确恢复范围。');
      }
      final recipeIds = data.recipes.map((r) => r.id).toSet();
      final restaurantIds = data.restaurants.map((r) => r.id).toSet();
      if (recipeIds.length != data.recipes.length ||
          restaurantIds.length != data.restaurants.length ||
          data.selectedMenu.any((id) => !recipeIds.contains(id)) ||
          data.selectedMenu.toSet().length != data.selectedMenu.length ||
          !const ['system', 'light', 'dark'].contains(data.themeMode)) {
        throw const FormatException('备份内容不完整，无法恢复。');
      }
      final photos = <String, Uint8List>{};
      final sources = <String, Uint8List>{};
      for (final name in _imageLists(data).expand((paths) => paths).toSet()) {
        final photo = archive.findFile(name);
        if (!name.startsWith('photos/') || photo == null || !photo.isFile) {
          throw const FormatException('备份缺少照片，无法完整恢复。');
        }
        photos[name] = photo.content;
        final source = archive.findFile('$name.source.json');
        if (source != null) sources[name] = source.content;
      }
      return PreparedBackup(
        data,
        photos,
        sources: sources,
        summary:
            '本应用备份：${data.recipes.length} 道菜谱、${data.restaurants.length} 家餐厅、${photos.length} 张照片。',
      );
    });
    try {
      await validateLegacyPatterns(backup.data.patternTagRules.keys.toList());
    } on FormatException catch (error) {
      throw FormatException('备份中的标签规则无法在当前设备使用：${error.message}');
    }
    return backup;
  }

  static Future<void> restore(MenuStore store, PreparedBackup backup) async {
    final directory = Directory('${store.directory.path}/restore_${newId()}');
    await directory.create();
    var committed = false;
    try {
      final paths = <String, String>{};
      for (final photo in backup.photos.entries) {
        final destination =
            '${directory.path}/${newId()}.${photo.key.split('.').last}';
        await File(destination).writeAsBytes(photo.value, flush: true);
        final source = backup.sources[photo.key];
        if (source != null) {
          await PhotoStorage.sourceFile(
            destination,
          ).writeAsBytes(source, flush: true);
        }
        paths[photo.key] = destination;
      }
      for (final list in _imageLists(backup.data)) {
        for (var i = 0; i < list.length; i++) {
          list[i] = paths[list[i]]!;
        }
      }
      await store.replace(backup.data);
      committed = true;
    } finally {
      if (!committed) await directory.delete(recursive: true);
    }
  }
}
