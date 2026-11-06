import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import 'photo_viewer.dart';
export 'photo_crop_page.dart' show cropPhoto;
export 'photo_widget.dart' show LocalPhoto;

Future<List<String>> choosePhotos(
  BuildContext context, {
  bool camera = false,
  bool single = false,
}) async {
  final store = MenuScope.of(context);
  var paths = <String>[];
  await performAction(context, () async {
    final picker = ImagePicker();
    final List<XFile> selected;
    if (camera || single) {
      final photo = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
      );
      selected = photo == null ? [] : [photo];
    } else {
      selected = await picker.pickMultiImage();
    }
    paths = await Future.wait(
      selected.map((photo) => store.keepImage(photo.path)),
    );
  });
  return paths;
}

Future<void> showPhotoViewer(
  BuildContext context,
  List<String> paths,
  int initial, {
  String? title,
  ValueChanged<int>? onPageChanged,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => PhotoViewer(
      paths: [...paths],
      initial: initial,
      title: title,
      onPageChanged: onPageChanged,
    ),
  ),
);

Future<void> savePhoto(BuildContext context, String path) async {
  await performAction(context, () async {
    final fileName = path.split('/').last;
    final bytes = await File(path).readAsBytes();
    final result = await FilePicker.saveFile(
      dialogTitle: '保存照片',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [fileName.split('.').last],
      bytes: bytes,
    );
    if (result == null) return;
    if (context.mounted) showToast(context, '照片已保存');
  });
}

Future<void> sharePhoto(
  BuildContext context,
  String path, {
  String? title,
}) async {
  final box = context.findRenderObject()! as RenderBox;
  final origin = Rect.fromCenter(
    center: box.localToGlobal(Offset(box.size.width - 28, 28)),
    width: 1,
    height: 1,
  );
  await performAction(context, () async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        title: title,
        sharePositionOrigin: origin,
      ),
    );
  });
}
