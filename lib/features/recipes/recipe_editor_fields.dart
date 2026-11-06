import '../../ui/menu_bottom_sheet.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../ui/menu_icon.dart';
import 'recipe_photos.dart';

class RecipeFieldLabel extends StatelessWidget {
  const RecipeFieldLabel(this.text, {super.key, this.hint});
  final String text;
  final String? hint;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (hint != null)
            TextSpan(
              text: '   $hint',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    ),
  );
}

class RecipePhotoFields extends StatelessWidget {
  const RecipePhotoFields({
    super.key,
    required this.paths,
    required this.busy,
    required this.onPick,
    required this.onAction,
  });
  final List<String> paths;
  final bool busy;
  final ValueChanged<bool> onPick;
  final void Function(int, String) onAction;

  Future<void> _choose(BuildContext context, {bool replace = false}) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final camera = await showMenuBottomSheet<bool>(
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
      if (camera == null) return;
      if (replace) {
        onAction(0, camera ? 'replaceCamera' : 'replace');
      } else {
        onPick(camera);
      }
    } else if (replace) {
      onAction(0, 'replace');
    } else {
      onPick(false);
    }
  }

  Future<void> _manage(BuildContext context, int index) async {
    final action = await showMenuBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0)
              ListTile(
                title: const Text('设为封面'),
                onTap: () => Navigator.pop(context, 'cover'),
              ),
            ListTile(
              title: const Text('裁剪照片'),
              onTap: () => Navigator.pop(context, 'crop'),
            ),
            ListTile(
              title: const Text('移除照片'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action != null) onAction(index, action);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RecipeFieldLabel('照片', hint: '可选'),
        if (paths.isEmpty)
          Material(
            color: scheme.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: busy ? null : () => _choose(context),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .25),
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MenuIcon(
                      Icons.add_photo_alternate_outlined,
                      size: 29,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '添加菜品照片',
                      style: TextStyle(fontSize: 14, color: scheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => showRecipePhotos(context, paths, 0),
                    onLongPress: busy ? null : () => _manage(context, 0),
                    child: RecipePhoto(path: paths.first),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xc914251b),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          '封面',
                          style: TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => _choose(context, replace: true),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xdfffffff),
                        foregroundColor: const Color(0xff111720),
                        minimumSize: const Size(64, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      icon: const MenuIcon(
                        Icons.add_photo_alternate_outlined,
                        size: 17,
                      ),
                      label: const Text('更换'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (var i = 0; i < paths.length; i++)
                SizedBox.square(
                  dimension: 58,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Semantics(
                            label: '菜品照片 ${i + 1}，长按管理照片',
                            button: true,
                            child: GestureDetector(
                              onTap: () => showRecipePhotos(context, paths, i),
                              onLongPress: busy
                                  ? null
                                  : () => _manage(context, i),
                              child: RecipePhoto(path: paths[i]),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: SizedBox.square(
                          dimension: 32,
                          child: IconButton(
                            tooltip: '移除照片 ${i + 1}',
                            padding: EdgeInsets.zero,
                            onPressed: busy
                                ? null
                                : () => onAction(i, 'remove'),
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xdfffffff),
                                shape: BoxShape.circle,
                              ),
                              child: const MenuIcon(
                                Icons.delete_outline,
                                size: 15,
                                color: Color(0xff111720),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox.square(
                dimension: 58,
                child: OutlinedButton(
                  onPressed: busy ? null : () => _choose(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const MenuIcon(Icons.add, size: 24),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
