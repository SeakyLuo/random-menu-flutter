import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';

class PhotoStorage {
  PhotoStorage._(this.directory, this.installation);
  final Directory directory;
  final String installation;
  static const _channel = MethodChannel(
    'com.seakyluo.random_menu/photo_library',
  );

  static Future<PhotoStorage> open(Directory directory) async {
    final identity = File('${directory.path}/photo_library_id');
    final exists = await identity.exists();
    final installation = exists ? await identity.readAsString() : newId();
    if (!exists) {
      await identity.writeAsString(installation, flush: true);
    }
    return PhotoStorage._(directory, installation);
  }

  static File sourceFile(String path) => File('$path.source.json');

  Future<List<String>> pick({bool camera = false, bool single = false}) async {
    final files = <String>[];
    if ((Platform.isAndroid || Platform.isIOS) && !camera) {
      final selected = await _channel.invokeListMethod<dynamic>('pick', {
        'single': single,
      });
      for (final item in selected!) {
        final photo = Map<String, dynamic>.from(item as Map);
        final path = photo['path'] as String;
        await _writeSource(path, photo['source'] as String);
        files.add(path);
      }
    } else {
      final picker = ImagePicker();
      final List<XFile> selected;
      if (camera || single) {
        final file = await picker.pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
        );
        selected = file == null ? [] : [file];
      } else {
        selected = await picker.pickMultiImage(requestFullMetadata: true);
      }
      for (final file in selected) {
        final source = await _channel.invokeMethod<String>(
          camera ? 'retainCapture' : 'retainFile',
          {'path': file.path},
        );
        final path = camera
            ? file.path
            : (await File(file.path).copy(
                '${Directory.systemTemp.path}/picked_${newId()}.${file.path.split('.').last}',
              )).path;
        await _writeSource(path, source!);
        files.add(path);
      }
    }
    return files;
  }

  Future<void> _writeSource(String path, String source) async {
    await sourceFile(path).writeAsString(
      jsonEncode({
        'installation': installation,
        'platform': Platform.operatingSystem,
        'source': source,
        'temporary': true,
      }),
      flush: true,
    );
  }

  Future<String> keep(String source, {String? originalOf}) async {
    final images = Directory('${directory.path}/images');
    await images.create(recursive: true);
    final format = Platform.isMacOS ? CompressFormat.jpeg : CompressFormat.webp;
    final extension = Platform.isMacOS ? 'jpg' : 'webp';
    final destination = '${images.path}/${newId()}.$extension';
    final buffer = await ui.ImmutableBuffer.fromFilePath(source);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    descriptor.dispose();
    buffer.dispose();
    final compressed = await FlutterImageCompress.compressWithFile(
      source,
      format: format,
      quality: 80,
      minWidth: width,
      minHeight: height,
      inSampleSize: 1,
    );
    if (compressed == null || compressed.isEmpty) {
      throw const FormatException('图片压缩失败，请重新选择照片');
    }
    await File(destination).writeAsBytes(compressed, flush: true);
    final metadata = sourceFile(originalOf ?? source);
    if (await metadata.exists()) {
      final origin =
          jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
      origin.remove('temporary');
      await sourceFile(
        destination,
      ).writeAsString(jsonEncode(origin), flush: true);
    }
    return destination;
  }

  Future<void> releaseSelection(String path) async {
    final metadata = sourceFile(path);
    final origin =
        jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
    if (origin['temporary'] == true) {
      await File(path).delete();
      await metadata.delete();
    }
  }

  Future<bool> hasOriginal(String path) async {
    final metadata = sourceFile(path);
    if (!await metadata.exists()) return false;
    final source =
        jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
    return source['installation'] == installation &&
        source['platform'] == Platform.operatingSystem;
  }

  Future<String> original(String path) async {
    final source =
        jsonDecode(await sourceFile(path).readAsString())
            as Map<String, dynamic>;
    return (await _channel.invokeMethod<String>('original', {
      'source': source['source'],
    }))!;
  }
}
