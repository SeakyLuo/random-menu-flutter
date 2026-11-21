import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_action_sheet.dart';
import '../../ui/menu_bottom_sheet.dart';
import '../media/media_actions.dart' show LocalPhoto;

List<String> visitPhotoPaths(Iterable<VisitDish> items, List<String> images) =>
    {for (final dish in items) ...dish.imagePaths, ...images}.toList();

Future<({String? path})?> showVisitPhotoPicker(
  BuildContext context,
  List<String> paths, {
  bool allowAlbum = false,
}) => showMenuBottomSheet<({String? path})>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MenuSheetHeader('选择照片'),
        const SizedBox(height: 8),
        Flexible(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: paths.length,
            itemBuilder: (context, index) => Semantics(
              button: true,
              label: '使用本次照片 ${index + 1}',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(context, (path: paths[index])),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LocalPhoto(path: paths[index]),
                ),
              ),
            ),
          ),
        ),
        if (allowAlbum) ...[
          const SizedBox(height: 8),
          MenuSheetActions(
            actions: [
              MenuSheetAction(
                icon: Icons.photo_library_outlined,
                label: '从相册选择',
                onTap: () => Navigator.pop(context, (path: null)),
              ),
            ],
          ),
        ],
      ],
    ),
  ),
);
