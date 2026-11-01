import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import 'media_actions.dart';

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.paths,
    required this.initial,
    this.title,
  });
  final List<String> paths;
  final int initial;
  final String? title;
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _busy = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _action(String action) async {
    setState(() => _busy = true);
    final path = widget.paths[_index];
    if (action == 'save') {
      await savePhoto(context, path);
    } else {
      await sharePhoto(context, path, title: widget.title);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${_index + 1} / ${widget.paths.length}'),
      actions: [
        PopupMenuButton<String>(
          icon: const MenuIcon(Icons.more_horiz),
          tooltip: '照片操作',
          enabled: !_busy,
          onSelected: _action,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'save', child: Text('保存照片')),
            PopupMenuItem(value: 'share', child: Text('分享照片')),
          ],
        ),
      ],
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.paths.length,
      onPageChanged: (index) => setState(() => _index = index),
      itemBuilder: (_, index) => InteractiveViewer(
        child: Center(
          child: LocalPhoto(path: widget.paths[index], fit: BoxFit.contain),
        ),
      ),
    ),
  );
}
