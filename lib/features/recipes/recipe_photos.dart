import 'package:flutter/material.dart';
import '../media/media_actions.dart';

class RecipePhoto extends LocalPhoto {
  const RecipePhoto({super.key, required super.path, super.fit});
}

void showRecipePhotos(BuildContext context, List<String> paths, int initial) {
  showPhotoViewer(context, paths, initial);
}
