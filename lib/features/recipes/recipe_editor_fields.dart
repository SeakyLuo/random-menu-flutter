import '../../ui/menu_field_label.dart';
export '../../ui/menu_field_label.dart';
import 'package:flutter/material.dart';
import '../../ui/menu_icon.dart';
import 'recipe_photos.dart';
import '../../core/menu_store.dart';
import '../media/media_actions.dart' show showOriginalPhoto;
import '../media/photo_edit_actions.dart';

class RecipePhotoFields extends StatelessWidget {
  const RecipePhotoFields({
    super.key,
    required this.paths,
    required this.busy,
    required this.onPick,
    required this.onAction,
    required this.onOpen,
  });
  final List<String> paths;
  final bool busy;
  final ValueChanged<bool> onPick;
  final Future<void> Function(int, String) onAction;
  final ValueChanged<int> onOpen;

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
        const MenuFieldLabel('照片'),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < paths.length; i++)
                  SizedBox.square(
                    dimension: size,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Semantics(
                            label:
                                '照片 ${i + 1}${i == 0 ? '，封面' : ''}，点击预览，长按管理',
                            button: true,
                            child: GestureDetector(
                              onTap: busy ? null : () => onOpen(i),
                              onLongPress: busy
                                  ? null
                                  : () => _manage(context, i),
                              child: RecipePhoto(path: paths[i]),
                            ),
                          ),
                        ),
                        if (i == 0)
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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: SizedBox.square(
                            dimension: 36,
                            child: IconButton(
                              tooltip: '移除照片 ${i + 1}',
                              padding: EdgeInsets.zero,
                              onPressed: busy
                                  ? null
                                  : () => onAction(i, 'remove'),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: scheme.surface.withValues(alpha: .94),
                                  shape: BoxShape.circle,
                                ),
                                child: MenuIcon(
                                  Icons.close,
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
