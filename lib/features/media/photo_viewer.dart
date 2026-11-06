import '../../ui/menu_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui/menu_icon.dart';
import 'media_actions.dart';

class PhotoCaption {
  const PhotoCaption({required this.name, required this.note});
  final String name;
  final String note;
}

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.paths,
    required this.initial,
    this.title,
    this.captions,
    this.onPageChanged,
  });
  final List<String> paths;
  final int initial;
  final String? title;
  final List<PhotoCaption>? captions;
  final ValueChanged<int>? onPageChanged;
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _controller = PageController(
    initialPage: _multiple ? widget.initial + 1 : 0,
  );
  late int _index = widget.initial;
  bool _busy = false;
  bool _zoomed = false;
  bool get _multiple => widget.paths.length > 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _photoIndex(int page) => _multiple ? (page - 1) % widget.paths.length : 0;

  void _pageChanged(int page) {
    final index = _photoIndex(page);
    if (index == _index) return;
    setState(() {
      _index = index;
      _zoomed = false;
    });
    widget.onPageChanged?.call(index);
  }

  bool _finishPaging(ScrollEndNotification notification) {
    if (!_multiple) return false;
    final page = _controller.page!.round();
    if (page == 0) {
      _controller.jumpToPage(widget.paths.length);
    } else if (page == widget.paths.length + 1) {
      _controller.jumpToPage(1);
    }
    return false;
  }

  Future<void> _showActions() async {
    final path = widget.paths[_index];
    final action = await showMenuBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const MenuIcon(Icons.file_download_outlined),
              title: const Text('保存照片'),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            ListTile(
              leading: const MenuIcon(Icons.ios_share_rounded),
              title: const Text('分享照片'),
              onTap: () => Navigator.pop(context, 'share'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    setState(() => _busy = true);
    if (action == 'save') {
      await savePhoto(context, path);
    } else {
      await sharePhoto(context, path, title: widget.title);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.captions?[_index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            surface: Colors.black,
            onSurface: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: NotificationListener<ScrollEndNotification>(
                        onNotification: _finishPaging,
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: _multiple ? widget.paths.length + 2 : 1,
                          physics: _zoomed || !_multiple
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          onPageChanged: _pageChanged,
                          itemBuilder: (_, page) {
                            final index = _photoIndex(page);
                            return _ZoomPhoto(
                              key: ValueKey(page),
                              path: widget.paths[index],
                              active: index == _index,
                              onZoom: (zoomed) {
                                if (index == _index) {
                                  setState(() => _zoomed = zoomed);
                                }
                              },
                              onLongPress: _busy ? null : _showActions,
                            );
                          },
                        ),
                      ),
                    ),
                    if (!_zoomed && caption != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .25,
                          ),
                          child: SingleChildScrollView(
                            key: ValueKey(_index),
                            child: Column(
                              children: [
                                Text(
                                  caption.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (caption.note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    caption.note,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xa6ffffff),
                                      fontSize: 12,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_multiple && !_zoomed)
                          IgnorePointer(
                            child: Text(
                              '${_index + 1} / ${widget.paths.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 20 / 13,
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox.square(
                            dimension: 44,
                            child: IconButton(
                              tooltip: '关闭照片',
                              onPressed: () => Navigator.pop(context),
                              icon: const MenuIcon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _ZoomPhoto extends StatefulWidget {
  const _ZoomPhoto({
    super.key,
    required this.path,
    required this.active,
    required this.onZoom,
    required this.onLongPress,
  });
  final String path;
  final bool active;
  final ValueChanged<bool> onZoom;
  final VoidCallback? onLongPress;
  @override
  State<_ZoomPhoto> createState() => _ZoomPhotoState();
}

class _ZoomPhotoState extends State<_ZoomPhoto> {
  final _transform = TransformationController();
  bool _zoomed = false;

  @override
  void didUpdateWidget(covariant _ZoomPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _transform.value = Matrix4.identity();
      _zoomed = false;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _reportZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoom(zoomed);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Semantics(
      label: '照片，可双指缩放或双击放大还原，长按保存或分享',
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        onLongPress: widget.onLongPress,
        onDoubleTap: () {
          final center = constraints.biggest.center(Offset.zero);
          _transform.value = _zoomed
              ? Matrix4.identity()
              : (Matrix4.identity()
                  ..translateByDouble(-center.dx * 1.5, -center.dy * 1.5, 0, 1)
                  ..scaleByDouble(2.5, 2.5, 1, 1));
          _reportZoom();
        },
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 4,
          onInteractionUpdate: (_) => _reportZoom(),
          onInteractionEnd: (_) => _reportZoom(),
          child: Center(
            child: LocalPhoto(path: widget.path, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}
