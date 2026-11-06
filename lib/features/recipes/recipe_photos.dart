import 'package:flutter/material.dart';
import '../media/media_actions.dart';

class RecipePhoto extends LocalPhoto {
  const RecipePhoto({super.key, required super.path, super.fit});
}

Future<void> showRecipePhotos(
  BuildContext context,
  List<String> paths,
  int initial, {
  ValueChanged<int>? onPageChanged,
}) => showPhotoViewer(context, paths, initial, onPageChanged: onPageChanged);
