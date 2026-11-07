import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Caches a display-sized decode while keeping the stored file unchanged.
@immutable
class DisplayPhotoImage extends ImageProvider<DisplayPhotoImage> {
  const DisplayPhotoImage({
    required this.path,
    required this.width,
    required this.height,
    required this.fit,
  });

  final String path;
  final int width;
  final int height;
  final BoxFit fit;

  @override
  Future<DisplayPhotoImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    DisplayPhotoImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(),
    scale: 1,
    debugLabel: path,
  );

  Future<ui.Codec> _load() async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    return PaintingBinding.instance.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (intrinsicWidth, intrinsicHeight) {
        final source = ui.Size(
          intrinsicWidth.toDouble(),
          intrinsicHeight.toDouble(),
        );
        final fitted = applyBoxFit(
          fit,
          source,
          ui.Size(width.toDouble(), height.toDouble()),
        );
        final scale = math.min(
          1.0,
          fitted.destination.width / fitted.source.width,
        );
        return ui.TargetImageSize(
          width: (intrinsicWidth * scale).ceil(),
          height: (intrinsicHeight * scale).ceil(),
        );
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DisplayPhotoImage &&
      path == other.path &&
      width == other.width &&
      height == other.height &&
      fit == other.fit;

  @override
  int get hashCode => Object.hash(path, width, height, fit);
}
