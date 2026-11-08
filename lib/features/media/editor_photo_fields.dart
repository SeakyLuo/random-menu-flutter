import '../../ui/menu_field_label.dart';
import 'package:flutter/material.dart';
import '../../ui/menu_icon.dart';
import '../../core/menu_store.dart';
import 'media_actions.dart' show showOriginalPhoto, LocalPhoto;
import 'photo_edit_actions.dart';
import 'reorderable_photo_grid.dart';

class EditorPhotoFields extends StatelessWidget {
  const EditorPhotoFields({
    super.key,
    required this.paths,
    required this.busy,
    required this.onPick,
    required this.onAction,
    required this.onOpen,
    required this.onReorder,
    this.label = '照片',
    this.showCover = true,
    this.heroTagForIndex,
  });
  final List<String> paths;
  final bool busy;
  final ValueChanged<bool> onPick;
  final Future<void> Function(int, String) onAction;
  final ValueChanged<int> onOpen;
  final void Function(int from, int to) onReorder;
  final String label;
  final bool showCover;
  final Object Function(int)? heroTagForIndex;

  Future<void> _choose(BuildContext context) async {
    final camera = await choosePhotoSource(context);
    if (camera != null) onPick(camera);
  }

  Future<void> _manage(BuildContext context, int index) async {
    final path = paths[index];
    final hasOriginal = await MenuScope.of(context).photos.hasOriginal(path);
    if (!context.mounted) return;
    final action = await showPhotoEditMenu(
      context,
      isCover: index == 0,
      allowCover: showCover,
      hasOriginal: hasOriginal,
    );
    if (action == null || !context.mounted) return;
    if (action == 'original') {
      await showOriginalPhoto(context, path);
    } else {
      await onAction(index, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuFieldLabel(
          label,
          trailing: paths.length > 1
              ? Text(
                  '长按拖动排序',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : null,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth - 16) / 3;
            return ReorderablePhotoGrid(
              paths: paths,
              enabled: !busy,
              onReorder: onReorder,
              itemBuilder: (context, i) => SizedBox.square(
                dimension: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Semantics(
                        label:
                            '照片 ${i + 1}${showCover && i == 0 ? '，封面' : ''}，点击预览，长按拖动排序',
                        button: true,
                        child: GestureDetector(
                          onTap: busy ? null : () => onOpen(i),
                          child: heroTagForIndex == null
                              ? LocalPhoto(path: paths[i])
                              : Hero(
                                  tag: heroTagForIndex!(i),
                                  child: LocalPhoto(path: paths[i]),
                                ),
                        ),
                      ),
                    ),
                    if (showCover && i == 0)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xc914251b),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '封面',
                            style: TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: SizedBox.square(
                        dimension: 36,
                        child: IconButton(
                          tooltip: '照片 ${i + 1} 操作',
                          padding: EdgeInsets.zero,
                          onPressed: busy ? null : () => _manage(context, i),
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: .94),
                              shape: BoxShape.circle,
                            ),
                            child: MenuIcon(
                              Icons.more_horiz,
                              size: 15,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: [
                SizedBox.square(
                  dimension: size,
                  child: TextButton(
                    onPressed: busy ? null : () => _choose(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: scheme.onSurface.withValues(alpha: .04),
                      foregroundColor: scheme.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MenuIcon(Icons.add_photo_alternate_outlined, size: 24),
                        SizedBox(height: 8),
                        Text('添加照片', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
