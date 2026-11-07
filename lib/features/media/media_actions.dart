import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';
import 'photo_viewer.dart';
import 'photo_edit_actions.dart';
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
    final selected = await store.photos.pick(camera: camera, single: single);
    final kept = <String>[];
    for (final path in selected) {
      kept.add(await store.keepImage(path));
    }
    for (final path in selected) {
      await store.photos.releaseSelection(path);
    }
    paths = kept;
  });
  return paths;
}

Future<void> showPhotoViewer(
  BuildContext context,
  List<String> paths,
  int initial, {
  String? title,
  List<PhotoCaption>? captions,
  ValueChanged<int>? onReturnIndex,
  Object? Function(int)? heroTagForIndex,
  PhotoEditCallback? onEdit,
}) => Navigator.of(context).push<void>(
  PageRouteBuilder<void>(
    transitionDuration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 280,
    ),
    reverseTransitionDuration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
    ),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (_, _, _) => PhotoViewer(
      paths: [...paths],
      initial: initial,
      title: title,
      captions: captions,
      onReturnIndex: onReturnIndex,
      heroTagForIndex: heroTagForIndex,
      onEdit: onEdit,
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

Future<void> showOriginalPhoto(BuildContext context, String path) =>
    performAction(context, () async {
      final original = await MenuScope.of(context).photos.original(path);
      try {
        if (context.mounted) {
          await showPhotoViewer(context, [original], 0, title: '原图');
        }
      } finally {
        await File(original).delete();
      }
    });

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
