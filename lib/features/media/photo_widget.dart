import '../../ui/menu_icon.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class LocalPhoto extends StatelessWidget {
  const LocalPhoto({super.key, required this.path, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => Image.file(
    File(path),
    fit: fit,
    errorBuilder: (_, _, _) => ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: const Center(
        child: MenuIcon(Icons.broken_image_outlined, size: 32),
      ),
    ),
  );
}
