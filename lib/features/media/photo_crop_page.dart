import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/widgets.dart';

enum _CropRatio { original, square, landscape, free }

enum _CropGesture { moveCrop, topLeft, bottomRight, moveImage }

Future<String?> cropPhoto(BuildContext context, String path) => Navigator.of(
  context,
).push<String>(MaterialPageRoute(builder: (_) => _PhotoCropPage(path: path)));

class _PhotoCropPage extends StatefulWidget {
  const _PhotoCropPage({required this.path});
  final String path;
  @override
  State<_PhotoCropPage> createState() => _PhotoCropPageState();
}

class _PhotoCropPageState extends State<_PhotoCropPage> {
  ui.Image? _image;
  bool _failed = false;
  bool _saving = false;
  bool _finished = false;
  _CropRatio _ratio = _CropRatio.original;
  Size _viewport = Size.zero;
  Rect _imageRect = Rect.zero;
  Rect _crop = Rect.zero;
  Rect _startImage = Rect.zero;
  Rect _startCrop = Rect.zero;
  Offset _startFocal = Offset.zero;
  int _pointers = 1;
  double _startScale = 1;
  _CropGesture _gesture = _CropGesture.moveCrop;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final bytes = await File(widget.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image = frame.image;
        _viewport = Size.zero;
      });
    } catch (error, stack) {
      debugPrint('Photo decode failed: $error\n$stack');
      if (!mounted) return;
      setState(() => _failed = true);
      showToast(context, '照片未能打开，请重新选择');
    }
  }

  double? get _aspect => switch (_ratio) {
    _CropRatio.original => _image!.width / _image!.height,
    _CropRatio.square => 1,
    _CropRatio.landscape => 4 / 3,
    _CropRatio.free => null,
  };

  void _reset() {
    final image = _image!;
    final fit = math.min(
      (_viewport.width - 32) / image.width,
      (_viewport.height - 32) / image.height,
    );
    _imageRect = Rect.fromCenter(
      center: _viewport.center(Offset.zero),
      width: image.width * fit,
      height: image.height * fit,
    );
    final aspect = _aspect ?? image.width / image.height;
    var width = _imageRect.width;
    var height = width / aspect;
    if (height > _imageRect.height) {
      height = _imageRect.height;
      width = height * aspect;
    }
    _crop = Rect.fromCenter(
      center: _imageRect.center,
      width: width,
      height: height,
    );
  }

  Rect get _bounds => _imageRect.intersect(Offset.zero & _viewport);

  void _start(ScaleStartDetails details) {
    _pointers = details.pointerCount;
    _startScale = 1;
    _startFocal = details.localFocalPoint;
    _startImage = _imageRect;
    _startCrop = _crop;
    if ((_startFocal - _crop.topLeft).distance <= 30) {
      _gesture = _CropGesture.topLeft;
    } else if ((_startFocal - _crop.bottomRight).distance <= 30) {
      _gesture = _CropGesture.bottomRight;
    } else {
      _gesture = _crop.contains(_startFocal)
          ? _CropGesture.moveCrop
          : _CropGesture.moveImage;
    }
  }

  Rect _keepImageOverCrop(Rect proposed) {
    final minScale = math.max(
      _crop.width / proposed.width,
      _crop.height / proposed.height,
    );
    if (minScale > 1) {
      proposed = Rect.fromCenter(
        center: proposed.center,
        width: proposed.width * minScale,
        height: proposed.height * minScale,
      );
    }
    return Rect.fromLTWH(
      proposed.left.clamp(_crop.right - proposed.width, _crop.left),
      proposed.top.clamp(_crop.bottom - proposed.height, _crop.top),
      proposed.width,
      proposed.height,
    );
  }

  void _update(ScaleUpdateDetails details) {
    if (_pointers != details.pointerCount) {
      _pointers = details.pointerCount;
      _startFocal = details.localFocalPoint;
      _startImage = _imageRect;
      _startCrop = _crop;
      _startScale = details.scale;
      _gesture = details.pointerCount > 1
          ? _CropGesture.moveImage
          : _CropGesture.moveCrop;
      return;
    }
    final delta = details.localFocalPoint - _startFocal;
    setState(() {
      if (details.pointerCount > 1 || _gesture == _CropGesture.moveImage) {
        final baseWidth =
            math.min(
              (_viewport.width - 32) / _image!.width,
              (_viewport.height - 32) / _image!.height,
            ) *
            _image!.width;
        final scale = (details.scale / _startScale).clamp(
          .25,
          math.max(.25, baseWidth * 12 / _startImage.width),
        );
        final proposed = Rect.fromLTWH(
          details.localFocalPoint.dx +
              (_startImage.left - _startFocal.dx) * scale,
          details.localFocalPoint.dy +
              (_startImage.top - _startFocal.dy) * scale,
          _startImage.width * scale,
          _startImage.height * scale,
        );
        _imageRect = _keepImageOverCrop(proposed);
        return;
      }
      final bounds = _bounds;
      if (_gesture == _CropGesture.moveCrop) {
        _crop = Rect.fromLTWH(
          (_startCrop.left + delta.dx).clamp(
            bounds.left,
            bounds.right - _startCrop.width,
          ),
          (_startCrop.top + delta.dy).clamp(
            bounds.top,
            bounds.bottom - _startCrop.height,
          ),
          _startCrop.width,
          _startCrop.height,
        );
        return;
      }
      final topLeft = _gesture == _CropGesture.topLeft;
      final anchor = topLeft ? _startCrop.bottomRight : _startCrop.topLeft;
      final moving =
          (topLeft ? _startCrop.topLeft : _startCrop.bottomRight) + delta;
      final maxWidth = topLeft
          ? anchor.dx - bounds.left
          : bounds.right - anchor.dx;
      final maxHeight = topLeft
          ? anchor.dy - bounds.top
          : bounds.bottom - anchor.dy;
      var width = (moving.dx - anchor.dx).abs().clamp(
        math.min(64.0, maxWidth),
        maxWidth,
      );
      var height = (moving.dy - anchor.dy).abs().clamp(
        math.min(64.0, maxHeight),
        maxHeight,
      );
      final aspect = _aspect;
      if (aspect != null) {
        width = math.min(
          math.max(width, height * aspect),
          math.min(maxWidth, maxHeight * aspect),
        );
        height = width / aspect;
      }
      _crop = Rect.fromLTWH(
        topLeft ? anchor.dx - width : anchor.dx,
        topLeft ? anchor.dy - height : anchor.dy,
        width.toDouble(),
        height.toDouble(),
      );
    });
  }

  Future<void> _save() async {
    final store = MenuScope.of(context);
    setState(() => _saving = true);
    String? result;
    final success = await performAction(context, () async {
      final image = _image!;
      final scale = image.width / _imageRect.width;
      final source = Rect.fromLTWH(
        (_crop.left - _imageRect.left) * scale,
        (_crop.top - _imageRect.top) * scale,
        _crop.width * scale,
        _crop.height * scale,
      );
      final width = math.max(1, source.width.round());
      final height = math.max(1, source.height.round());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        source,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(width, height);
      picture.dispose();
      final bytes = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      final file = File(
        '${store.directory.path}/images/${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      result = file.path;
    }, success: '裁剪已完成');
    if (!mounted) return;
    if (success) {
      setState(() => _finished = true);
      Navigator.pop(context, result);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving || _finished,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('裁剪照片'),
        actions: [
          TextButton(
            onPressed: _image == null || _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
      body: _failed
          ? EmptyState(
              icon: Icons.broken_image_outlined,
              title: '照片未能打开',
              message: '返回后重新选择照片。',
              actionLabel: '返回',
              onAction: () => Navigator.pop(context),
            )
          : _image == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        if (_viewport != size) {
                          _viewport = size;
                          _reset();
                        }
                        return GestureDetector(
                          onScaleStart: _saving ? null : _start,
                          onScaleUpdate: _saving ? null : _update,
                          child: CustomPaint(
                            size: size,
                            painter: _CropPainter(
                              image: _image!,
                              imageRect: _imageRect,
                              crop: _crop,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text(
                      '拖动框内选择区域，拖动对角调节大小，双指移动或缩放照片。',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final ratio in _CropRatio.values)
                          ChoiceChip(
                            label: Text(switch (ratio) {
                              _CropRatio.original => '原图比例',
                              _CropRatio.square => '正方形',
                              _CropRatio.landscape => '4:3',
                              _CropRatio.free => '自由',
                            }),
                            selected: _ratio == ratio,
                            onSelected: _saving
                                ? null
                                : (_) => setState(() {
                                    _ratio = ratio;
                                    _reset();
                                  }),
                          ),
                        TextButton(
                          onPressed: _saving ? null : () => setState(_reset),
                          child: const Text('重置裁剪'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.imageRect,
    required this.crop,
    required this.color,
  });
  final ui.Image image;
  final Rect imageRect;
  final Rect crop;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(const Color(0xff18231d), BlendMode.src);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      imageRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addRect(crop)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = const Color(0x99000000));
    canvas.drawRect(
      crop,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final grid = Paint()
      ..color = const Color(0x80ffffff)
      ..strokeWidth = .7;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(crop.left + crop.width * i / 3, crop.top),
        Offset(crop.left + crop.width * i / 3, crop.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(crop.left, crop.top + crop.height * i / 3),
        Offset(crop.right, crop.top + crop.height * i / 3),
        grid,
      );
    }
    final handles = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawPath(
      Path()
        ..moveTo(crop.left, crop.top + 18)
        ..lineTo(crop.left, crop.top)
        ..lineTo(crop.left + 18, crop.top),
      handles,
    );
    canvas.drawPath(
      Path()
        ..moveTo(crop.right - 18, crop.bottom)
        ..lineTo(crop.right, crop.bottom)
        ..lineTo(crop.right, crop.bottom - 18),
      handles,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image ||
      old.imageRect != imageRect ||
      old.crop != crop ||
      old.color != color;
}
