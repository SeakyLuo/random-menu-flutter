import 'dart:io';
import 'package:flutter/material.dart';
import '../../ui/menu_action_sheet.dart';

class PhotoEditResult {
  const PhotoEditResult({required this.path, required this.coverPath});
  final String? path;
  final String? coverPath;
}

typedef PhotoEditCallback =
    Future<PhotoEditResult> Function(String path, String action);

enum PhotoSource { album, camera, visit }

Future<PhotoSource?> choosePhotoSource(
  BuildContext context, {
  bool hasVisitPhotos = false,
}) async {
  final canTakePhoto = Platform.isAndroid || Platform.isIOS;
  if (!canTakePhoto && !hasVisitPhotos) return PhotoSource.album;
  return showMenuActionSheet<PhotoSource>(
    context: context,
    title: '添加照片',
    actions: (context) => [
      MenuSheetAction(
        icon: Icons.photo_library_outlined,
        label: '从相册选择',
        onTap: () => Navigator.pop(context, PhotoSource.album),
      ),
      if (canTakePhoto)
        MenuSheetAction(
          icon: Icons.camera_alt_outlined,
          label: '拍照',
          onTap: () => Navigator.pop(context, PhotoSource.camera),
        ),
      if (hasVisitPhotos)
        MenuSheetAction(
          icon: Icons.photo_library_outlined,
          label: '从本次消费记录中选择',
          onTap: () => Navigator.pop(context, PhotoSource.visit),
        ),
    ],
  );
}

Future<String?> showPhotoEditMenu(
  BuildContext context, {
  required bool isCover,
  bool allowCover = true,
  bool hasOriginal = false,
}) => showMenuActionSheet<String>(
  context: context,
  title: '图片操作',
  actions: (context) => [
    if (hasOriginal)
      MenuSheetAction(
        icon: Icons.photo_outlined,
        label: '查看原图',
        onTap: () => Navigator.pop(context, 'original'),
      ),
    MenuSheetAction(
      icon: Icons.crop,
      label: '编辑图片',
      onTap: () => Navigator.pop(context, 'crop'),
    ),
    if (allowCover && !isCover)
      MenuSheetAction(
        icon: Icons.photo_outlined,
        label: '设为封面',
        onTap: () => Navigator.pop(context, 'cover'),
      ),
    MenuSheetAction(
      icon: Icons.delete_outline,
      label: '删除图片',
      destructive: true,
      onTap: () => Navigator.pop(context, 'remove'),
    ),
  ],
);
