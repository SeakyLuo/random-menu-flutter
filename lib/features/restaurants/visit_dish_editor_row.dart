import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import 'restaurant_food_summary.dart';

class VisitDishEditorRow extends StatelessWidget {
  const VisitDishEditorRow({
    super.key,
    required this.dish,
    required this.package,
    required this.index,
    required this.onEdit,
    required this.confirmRemove,
    required this.onRemove,
  });

  final VisitDish dish;
  final VisitPackage? package;
  final int index;
  final VoidCallback onEdit;
  final Future<bool> Function() confirmRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: scheme.onSurface.withValues(alpha: .8),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Dismissible(
        key: ObjectKey(dish),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => confirmRemove(),
        onDismissed: (_) => onRemove(),
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: MenuIcon(Icons.delete_outline, color: scheme.onErrorContainer),
        ),
        child: Material(
          color: scheme.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: dish.imagePaths.isNotEmpty,
                label: '查看${dish.name}图片',
                child: GestureDetector(
                  onTap: dish.imagePaths.isEmpty
                      ? null
                      : () => showPhotoViewer(
                          context,
                          dish.imagePaths,
                          0,
                          title: dish.name,
                        ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox.square(
                      dimension: 80,
                      child: dish.imagePaths.isEmpty
                          ? ColoredBox(
                              color: scheme.surfaceContainer,
                              child: Center(
                                child: MenuIcon(
                                  Icons.ramen_dining_outlined,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : LocalPhoto(path: dish.imagePaths.first),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                dish.name.isEmpty ? '填写菜名' : dish.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (package == null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '¥${money(dish.price)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (package != null || dish.quantity > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              [
                                if (package != null)
                                  visitPackageLabel(package!),
                                if (dish.quantity > 1) '${dish.quantity} 份',
                              ].join(' · '),
                              style: secondary.copyWith(fontSize: 12),
                            ),
                          ),
                        if (dish.note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              dish.note,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: '拖动调整${dish.name}顺序',
                  child: SizedBox(
                    width: 36,
                    height: 80,
                    child: Center(
                      child: MenuIcon(
                        Icons.drag_indicator,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
