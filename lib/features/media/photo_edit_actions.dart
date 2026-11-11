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

Future<bool?> choosePhotoSource(BuildContext context) async {
  if (!Platform.isAndroid && !Platform.isIOS) return false;
  return showMenuActionSheet<bool>(
    context: context,
    title: '添加照片',
    actions: (context) => [
      MenuSheetAction(
        icon: Icons.photo_library_outlined,
        label: '从相册选择',
        onTap: () => Navigator.pop(context, false),
      ),
      MenuSheetAction(
        icon: Icons.camera_alt_outlined,
        label: '拍照',
        onTap: () => Navigator.pop(context, true),
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
