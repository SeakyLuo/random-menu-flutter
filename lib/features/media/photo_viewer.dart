import '../../ui/menu_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui/menu_icon.dart';
import 'media_actions.dart';
import 'photo_edit_actions.dart';
import '../../core/menu_store.dart';

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
    this.onReturnIndex,
    this.heroTagForIndex,
    this.onEdit,
  });
  final List<String> paths;
  final int initial;
  final String? title;
  final List<PhotoCaption>? captions;
  final ValueChanged<int>? onReturnIndex;
  final Object? Function(int)? heroTagForIndex;
  final PhotoEditCallback? onEdit;
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _paths = [...widget.paths];
  late String? _coverPath = _paths.first;
  bool get _editing => widget.onEdit != null;
  // Start well inside the virtual sequence so either swipe direction loops
  // without replacing the visible page at a physical boundary.
  late final _initialPage = _editing
      ? widget.initial
      : _multiple
      ? (1 << 20) - (1 << 20) % _paths.length + widget.initial
      : 0;
  late final _controller = PageController(initialPage: _initialPage);
  late int _index = widget.initial;
  late int _page = _initialPage;
  bool _busy = false;
  bool _zoomed = false;
  bool _closing = false;
  bool get _multiple => _paths.length > 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _photoIndex(int page) => page % _paths.length;

  void _pageChanged(int page) {
    final index = _photoIndex(page);
    final changed = index != _index;
    setState(() {
      _page = page;
      _index = index;
      if (changed) _zoomed = false;
    });
  }

  Future<void> _close() async {
    if (_closing || _busy) return;
    _closing = true;
    if (widget.onReturnIndex != null) {
      widget.onReturnIndex!(_index);
      // Update the covered source once, before Hero measures its return target.
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showActions() async {
    final path = _paths[_index];
    final hasOriginal = await MenuScope.of(context).photos.hasOriginal(path);
    if (!mounted) return;
    if (_editing) {
      final action = await showPhotoEditMenu(
        context,
        isCover: _paths[_index] == _coverPath,
        hasOriginal: hasOriginal,
      );
      if (action == null || !mounted) return;
      if (action == 'original') {
        await showOriginalPhoto(context, path);
      } else {
        await _edit(action);
      }
      return;
    }
    final action = await showMenuBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasOriginal)
              ListTile(
                leading: const MenuIcon(Icons.photo_outlined),
                title: const Text('查看原图'),
                onTap: () => Navigator.pop(context, 'original'),
              ),
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
    if (action == 'original') {
      await showOriginalPhoto(context, path);
    } else if (action == 'save') {
      await savePhoto(context, path);
    } else {
      await sharePhoto(context, path, title: widget.title);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit(String action) async {
    setState(() => _busy = true);
    final result = await widget.onEdit!(_paths[_index], action);
    if (!mounted) return;
    if (action == 'remove' && _paths.length == 1) {
      _busy = false;
      await _close();
      return;
    }
    setState(() {
      _coverPath = result.coverPath;
      if (action == 'remove') {
        _paths.removeAt(_index);
        if (_index == _paths.length) _index--;
        _page = _index;
        _zoomed = false;
      } else if (action != 'cover') {
        _paths[_index] = result.path!;
        _zoomed = false;
      }
      _busy = false;
    });
    if (action == 'remove') _controller.jumpToPage(_index);
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.captions?[_index];
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: _editing
                              ? _paths.length
                              : _multiple
                              ? null
                              : 1,
                          physics: _busy || _zoomed || !_multiple
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          onPageChanged: _pageChanged,
                          itemBuilder: (_, page) {
                            final index = _photoIndex(page);
                            return _ZoomPhoto(
                              key: ValueKey(page),
                              path: _paths[index],
                              heroTag: widget.heroTagForIndex?.call(index),
                              heroEnabled: page == _page,
                              active: page == _page,
                              onClose: _close,
                              onZoom: (zoomed) {
                                if (page == _page) {
                                  setState(() => _zoomed = zoomed);
                                }
                              },
                              onLongPress: _busy ? null : _showActions,
                            );
                          },
                        ),
                      ),
                      if (!_zoomed && caption != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.sizeOf(context).height * .25,
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
                          if ((_multiple || widget.title != null) && !_zoomed)
                            IgnorePointer(
                              child: Text(
                                _multiple
                                    ? '${_index + 1} / ${_paths.length}'
                                    : widget.title!,
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
                                onPressed: _close,
                                icon: const MenuIcon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: '照片操作',
                              onPressed: _busy ? null : _showActions,
                              icon: const MenuIcon(
                                Icons.more_horiz,
                                color: Colors.white,
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
    this.heroTag,
    required this.heroEnabled,
    required this.onClose,
  });
  final String path;
  final bool active;
  final ValueChanged<bool> onZoom;
  final VoidCallback? onLongPress;
  final Object? heroTag;
  final bool heroEnabled;
  final VoidCallback onClose;
  @override
  State<_ZoomPhoto> createState() => _ZoomPhotoState();
}

class _ZoomPhotoState extends State<_ZoomPhoto> {
  final _transform = TransformationController();
  bool _zoomed = false;

  @override
  void didUpdateWidget(covariant _ZoomPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active || oldWidget.path != widget.path) {
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
      label: '照片，可双指缩放或双击放大还原，长按查看照片操作',
      child: GestureDetector(
        onTap: widget.onClose,
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
          panEnabled: _zoomed,
          minScale: 1,
          maxScale: 4,
          onInteractionUpdate: (_) => _reportZoom(),
          onInteractionEnd: (_) => _reportZoom(),
          child: Center(
            child: widget.heroTag == null
                ? LocalPhoto(
                    path: widget.path,
                    fit: BoxFit.contain,
                    fullResolution: true,
                  )
                : HeroMode(
                    enabled: widget.heroEnabled,
                    child: Hero(
                      tag: widget.heroTag!,
                      flightShuttleBuilder: (_, animation, _, _, _) =>
                          AnimatedBuilder(
                            animation: animation,
                            builder: (_, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(
                                14 * (1 - animation.value),
                              ),
                              child: LocalPhoto(
                                path: widget.path,
                                fullResolution: true,
                              ),
                            ),
                          ),
                      child: LocalPhoto(
                        path: widget.path,
                        fit: BoxFit.contain,
                        fullResolution: true,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
