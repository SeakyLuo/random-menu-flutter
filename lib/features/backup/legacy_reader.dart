import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Strict readers for the two documented Android export schemas.
class LegacyObject {
  LegacyObject(Object? source, Set<String> allowed) {
    if (source is! Map<String, dynamic> ||
        source.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('备份含有尚未支持的旧版字段，未恢复任何数据。');
    }
    values = source;
  }
  late final Map<String, dynamic> values;
  bool has(String key) => values.containsKey(key);
  String text(String key, {bool required = false}) {
    if (!required && !has(key)) return '';
    final value = values[key];
    if (value is! String || (required && value.isEmpty)) fail();
    return value;
  }

  int integer(String key, {int? omitted}) {
    if (!has(key) && omitted != null) return omitted;
    final value = values[key];
    if (value is! int) fail();
    return value;
  }

  double number(String key) {
    final value = values[key];
    if (value is! num || !value.isFinite) fail();
    return value.toDouble();
  }

  bool flag(String key) {
    final value = values[key];
    if (value is! bool) fail();
    return value;
  }

  List<dynamic> list(String key, {bool omitted = false}) {
    if (omitted && !has(key)) return [];
    final value = values[key];
    if (value is! List) fail();
    return value;
  }

  List<dynamic> wrappedList(String key) {
    final wrapper = LegacyObject(values[key], {'list'});
    return wrapper.list('list');
  }

  Never fail() => throw const FormatException('备份中的旧版数据格式不正确，未恢复任何数据。');
}

List<String> legacyStrings(List<dynamic> values) {
  if (values.any((value) => value is! String)) {
    throw const FormatException('备份中的文字清单格式不正确，未恢复任何数据。');
  }
  return values.cast<String>().toList();
}

class LegacyFiles {
  LegacyFiles(Archive archive) {
    for (final entry in archive.files.where((entry) => entry.isFile)) {
      if (entries.containsKey(entry.name) || entry.isSymbolicLink) {
        throw const FormatException('备份存在重复文件或链接，无法完整恢复。');
      }
      entries[entry.name] = entry;
    }
  }
  final entries = <String, ArchiveFile>{};
  final photos = <String, Uint8List>{};
  final imageNames = <String>[];
  final imagePaths = <String>[];
  final _photoPaths = <String, String>{};

  dynamic json(String name) {
    final entry = entries[name];
    if (entry == null) {
      throw const FormatException('备份缺少必要的数据文件，无法完整恢复。');
    }
    return jsonDecode(utf8.decode(entry.content));
  }

  void collectImages(Set<String> jsonNames) {
    for (final entry in entries.entries) {
      if (jsonNames.contains(entry.key)) continue;
      const prefix = 'RandomMenuFood/';
      if (!entry.key.startsWith(prefix)) {
        throw const FormatException('备份含有尚未支持的文件，未恢复任何数据。');
      }
      final name = entry.key.substring(prefix.length);
      if (name.isEmpty ||
          name.contains('/') ||
          name.contains('\\') ||
          name == '.' ||
          name == '..') {
        throw const FormatException('备份的照片路径格式不正确，无法完整恢复。');
      }
      final destination = 'photos/${imageNames.length}_$name';
      photos[destination] = entry.value.content;
      _photoPaths[name] = destination;
      imageNames.add(name);
      imagePaths.add(destination);
    }
  }

  List<String> images(List<String> names, {String cover = ''}) {
    final ordered = [...names];
    if (cover.isNotEmpty) {
      ordered.remove(cover);
      ordered.insert(0, cover);
    }
    return ordered.map((name) {
      final path = _photoPaths[name];
      if (path == null) {
        throw const FormatException('备份缺少菜谱或消费记录引用的照片，无法完整恢复。');
      }
      return path;
    }).toList();
  }
}
