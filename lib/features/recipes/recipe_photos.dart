import 'package:flutter/material.dart';
import '../media/media_actions.dart';
import '../media/photo_edit_actions.dart';

class RecipePhoto extends LocalPhoto {
  const RecipePhoto({super.key, required super.path, super.fit});
}

Future<void> showRecipePhotos(
  BuildContext context,
  List<String> paths,
  int initial, {
  ValueChanged<int>? onReturnIndex,
  Object? Function(int)? heroTagForIndex,
  PhotoEditCallback? onEdit,
}) => showPhotoViewer(
  context,
  paths,
  initial,
  onReturnIndex: onReturnIndex,
  heroTagForIndex: heroTagForIndex,
  onEdit: onEdit,
);
