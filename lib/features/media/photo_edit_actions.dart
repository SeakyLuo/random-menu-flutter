import 'dart:io';
import 'package:flutter/material.dart';
import '../../ui/menu_bottom_sheet.dart';
import '../../ui/menu_icon.dart';

class PhotoEditResult {
  const PhotoEditResult({required this.path, required this.coverPath});
  final String? path;
  final String? coverPath;
}

typedef PhotoEditCallback =
    Future<PhotoEditResult> Function(String path, String action);

Future<bool?> choosePhotoSource(BuildContext context) async {
  if (!Platform.isAndroid && !Platform.isIOS) return false;
  return showMenuBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const MenuIcon(Icons.photo_library_outlined),
            title: const Text('从相册选择'),
            onTap: () => Navigator.pop(context, false),
          ),
          ListTile(
            leading: const MenuIcon(Icons.camera_alt_outlined),
            title: const Text('拍照'),
            onTap: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ),
  );
}

Future<String?> showPhotoEditMenu(
  BuildContext context, {
  required bool isCover,
  bool hasOriginal = false,
}) => showMenuBottomSheet<String>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasOriginal)
          ListTile(
            leading: const MenuIcon(Icons.photo_outlined),
            title: const Text('查看原图'),
            onTap: () => Navigator.pop(context, 'original'),
          ),
        ListTile(
          leading: const MenuIcon(Icons.crop),
          title: const Text('编辑图片'),
          onTap: () => Navigator.pop(context, 'crop'),
        ),
        if (!isCover)
          ListTile(
            leading: const MenuIcon(Icons.photo_outlined),
            title: const Text('设为封面'),
            onTap: () => Navigator.pop(context, 'cover'),
          ),
        ListTile(
          leading: const MenuIcon(Icons.delete_outline),
          title: const Text('删除图片'),
          onTap: () => Navigator.pop(context, 'remove'),
        ),
      ],
    ),
  ),
);
