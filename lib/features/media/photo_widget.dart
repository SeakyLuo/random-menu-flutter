import '../../ui/menu_icon.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'display_photo_image.dart';

ImageProvider<Object> _provider(
  BuildContext context,
  String path,
  BoxConstraints constraints,
  BoxFit fit,
  bool fullResolution,
) {
  if (fullResolution ||
      !constraints.hasBoundedWidth ||
      !constraints.hasBoundedHeight) {
    return FileImage(File(path));
  }
  final ratio = MediaQuery.devicePixelRatioOf(context);
  // Nearby layout sizes share a cache key without decoding below screen density.
  return DisplayPhotoImage(
    path: path,
    width: math.max(64, (constraints.maxWidth * ratio / 64).ceil() * 64),
    height: math.max(64, (constraints.maxHeight * ratio / 64).ceil() * 64),
    fit: fit,
  );
}

Widget _photo(
  BuildContext context,
  ImageProvider<Object> provider,
  BoxFit fit,
) => Image(
  image: provider,
  fit: fit,
  errorBuilder: (_, _, _) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: const Center(child: MenuIcon(Icons.broken_image_outlined, size: 32)),
  ),
);

class LocalPhoto extends StatelessWidget {
  const LocalPhoto({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.fullResolution = false,
  });
  final String path;
  final BoxFit fit;
  final bool fullResolution;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _photo(
      context,
      _provider(context, path, constraints, fit, fullResolution),
      fit,
    ),
  );
}

/// Retains the mounted card's image stream while another route covers it.
/// Image pauses its own listener with TickerMode; large photos may already
/// have left the LRU cache and would otherwise be decoded again on return.
class RetainedLocalPhoto extends StatelessWidget {
  const RetainedLocalPhoto({
    super.key,
    required this.path,
    this.fullResolution = false,
  });

  final String path;
  final bool fullResolution;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _RetainedPhoto(
      provider: _provider(
        context,
        path,
        constraints,
        BoxFit.cover,
        fullResolution,
      ),
    ),
  );
}

class _RetainedPhoto extends StatefulWidget {
  const _RetainedPhoto({required this.provider});
  final ImageProvider<Object> provider;
  @override
  State<_RetainedPhoto> createState() => _RetainedLocalPhotoState();
}

class _RetainedLocalPhotoState extends State<_RetainedPhoto> {
  late ImageStream _stream;
  final _listener = ImageStreamListener((image, _) => image.dispose());

  void _retain() {
    _stream = widget.provider.resolve(ImageConfiguration.empty);
    _stream.addListener(_listener);
  }

  @override
  void initState() {
    super.initState();
    _retain();
  }

  @override
  void didUpdateWidget(covariant _RetainedPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
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
  Widget build(BuildContext context) =>
      _photo(context, widget.provider, BoxFit.cover);
}
