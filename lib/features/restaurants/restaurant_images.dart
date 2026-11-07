import '../../ui/menu_popup.dart';
import '../../ui/menu_icon.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';

class RestaurantImages extends StatefulWidget {
  const RestaurantImages({
    super.key,
    required this.paths,
    this.onChanged,
    this.onBusyChanged,
    this.cover = false,
  });
  final List<String> paths;
  final ValueChanged<List<String>>? onChanged;
  final ValueChanged<bool>? onBusyChanged;
  final bool cover;
  @override
  State<RestaurantImages> createState() => _RestaurantImagesState();
}

class _RestaurantImagesState extends State<RestaurantImages> {
  bool busy = false;
  void setBusy(bool value) {
    setState(() => busy = value);
    widget.onBusyChanged?.call(value);
  }

  Future<void> pick(bool camera) async {
    setBusy(true);
    await performAction(context, () async {
      final images = await choosePhotos(context, camera: camera);
      if (mounted && images.isNotEmpty) {
        widget.onChanged!([...widget.paths, ...images]);
      }
    });
    if (mounted) setBusy(false);
  }

  Future<void> edit(int index, String action) async {
    final paths = [...widget.paths];
    switch (action) {
      case 'cover':
        final path = paths.removeAt(index);
        paths.insert(0, path);
      case 'previous':
        final path = paths.removeAt(index);
        paths.insert(index - 1, path);
      case 'next':
        final path = paths.removeAt(index);
        paths.insert(index + 1, path);
      case 'remove':
        if (!await confirmAction(
          context,
          title: '移除照片？',
          message: '从这次编辑中移除该照片，保存后生效。',
          confirmLabel: '移除',
        )) {
          return;
        }
        paths.removeAt(index);
      case 'crop':
        setBusy(true);
        String? result;
        final success = await performAction(context, () async {
          result = await cropPhoto(context, paths[index]);
        });
        if (!mounted) return;
        setBusy(false);
        if (!success || result == null) return;
        paths[index] = result!;
    }
    if (mounted) widget.onChanged!(paths);
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (var i = 0; i < widget.paths.length; i++)
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: busy
                        ? null
                        : () => showPhotoViewer(
                            context,
                            widget.paths,
                            i,
                            title: '照片',
                            heroTagForIndex: (index) => (this, index),
                          ),
                    child: Hero(
                      tag: (this, i),
                      child: Image.file(
                        File(widget.paths[i]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                          child: const MenuIcon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.cover && i == 0 && widget.onChanged != null)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Text(
                      '封面',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              if (widget.onChanged != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: MenuPopupButton<String>(
                    enabled: !busy,
                    tooltip: '照片操作',
                    icon: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: .94),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: MenuIcon(
                          Icons.more_horiz,
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: busy ? .38 : 1),
                        ),
                      ),
                    ),
                    onSelected: (value) => edit(i, value),
                    itemBuilder: (_) => [
                      if (widget.cover && i > 0)
                        const MenuPopupItem(
                          icon: Icons.image_outlined,
                          value: 'cover',
                          child: Text('设为封面'),
                        ),
                      if (i > 0)
                        const MenuPopupItem(
                          icon: Icons.arrow_upward,
                          value: 'previous',
                          child: Text('向前移动'),
                        ),
                      if (i < widget.paths.length - 1)
                        const MenuPopupItem(
                          icon: Icons.arrow_downward,
                          value: 'next',
                          child: Text('向后移动'),
                        ),
                      const MenuPopupItem(
                        icon: Icons.crop,
                        value: 'crop',
                        child: Text('裁剪照片'),
                      ),
                      const MenuPopupItem(
                        icon: Icons.delete_outline,
                        destructive: true,
                        value: 'remove',
                        child: Text('移除照片'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (widget.onChanged != null)
        SizedBox(
          width: 96,
          height: 96,
          child: MenuPopupButton<bool>(
            enabled: !busy,
            tooltip: '添加照片',
            onSelected: pick,
            itemBuilder: (_) => [
              const MenuPopupItem(
                icon: Icons.photo_library_outlined,
                value: false,
                child: Text('从相册选择'),
              ),
              if (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)
                const MenuPopupItem(
                  icon: Icons.camera_alt_outlined,
                  value: true,
                  child: Text('拍照'),
                ),
            ],
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MenuIcon(
                    busy
                        ? Icons.hourglass_top
                        : Icons.add_photo_alternate_outlined,
                  ),
                  const SizedBox(height: 6),
                  Text(busy ? '处理中' : '添加照片'),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
