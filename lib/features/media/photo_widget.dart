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

/// Retains the mounted card's image stream while another route covers it.
/// Image pauses its own listener with TickerMode; large photos may already
/// have left the LRU cache and would otherwise be decoded again on return.
class RetainedLocalPhoto extends StatefulWidget {
  const RetainedLocalPhoto({super.key, required this.path});

  final String path;

  @override
  State<RetainedLocalPhoto> createState() => _RetainedLocalPhotoState();
}

class _RetainedLocalPhotoState extends State<RetainedLocalPhoto> {
  late ImageStream _stream;
  final _listener = ImageStreamListener((image, _) => image.dispose());

  void _retain() {
    _stream = FileImage(File(widget.path)).resolve(ImageConfiguration.empty);
    _stream.addListener(_listener);
  }

  @override
  void initState() {
    super.initState();
    _retain();
  }

  @override
  void didUpdateWidget(covariant RetainedLocalPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _stream.removeListener(_listener);
      _retain();
    }
  }

  @override
  void dispose() {
    _stream.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocalPhoto(path: widget.path);
}
