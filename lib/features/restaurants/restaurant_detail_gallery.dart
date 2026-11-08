import 'package:flutter/material.dart';
import '../../ui/menu_segmented.dart';
import '../media/media_actions.dart';
import '../media/photo_widget.dart';
import 'restaurant_photo_deck.dart';

enum _PhotoGroup { dishes, environment }

class RestaurantDetailGallery extends StatefulWidget {
  const RestaurantDetailGallery({
    super.key,
    required this.name,
    required this.dishPaths,
    required this.environmentPaths,
  });

  final String name;
  final List<String> dishPaths;
  final List<String> environmentPaths;

  @override
  State<RestaurantDetailGallery> createState() =>
      _RestaurantDetailGalleryState();
}

class _RestaurantDetailGalleryState extends State<RestaurantDetailGallery> {
  late _PhotoGroup _group =
      widget.dishPaths.isEmpty && widget.environmentPaths.isNotEmpty
      ? _PhotoGroup.environment
      : _PhotoGroup.dishes;
  final _selectedPaths = <_PhotoGroup, String>{};

  @override
  void didUpdateWidget(covariant RestaurantDetailGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.environmentPaths.isEmpty) {
      _group = _PhotoGroup.dishes;
    } else if (widget.dishPaths.isEmpty) {
      _group = _PhotoGroup.environment;
    }
  }

  void _select(List<String> paths, int index) {
    final group = index < widget.dishPaths.length
        ? _PhotoGroup.dishes
        : _PhotoGroup.environment;
    setState(() {
      _group = group;
      _selectedPaths[group] = paths[index];
    });
  }

  void _open(List<String> paths, int index) {
    showPhotoViewer(
      context,
      paths,
      index,
      title: widget.name,
      onReturnIndex: (next) {
        if (mounted) _select(paths, next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final paths = [...widget.dishPaths, ...widget.environmentPaths];
    final selectedIndex = paths.indexOf(_selectedPaths[_group] ?? '');
    final index = selectedIndex >= 0
        ? selectedIndex
        : _group == _PhotoGroup.environment
        ? widget.dishPaths.length
        : 0;
    final colors = Theme.of(context).colorScheme;
    if (widget.dishPaths.isEmpty && widget.environmentPaths.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (paths.isNotEmpty)
            RestaurantPhotoDeck(
              key: ValueKey((_group, Object.hashAll(paths))),
              itemCount: paths.length,
              index: index,
              onChanged: (next) => _select(paths, next),
              onTap: () => _open(paths, index),
              itemBuilder: (context, photoIndex) => DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10172c21),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RetainedLocalPhoto(path: paths[photoIndex]),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (widget.dishPaths.isNotEmpty && widget.environmentPaths.isNotEmpty)
            Padding(
              padding: EdgeInsets.zero,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: MenuSegmented<_PhotoGroup>(
                    compact: true,
                    labels: const {
                      _PhotoGroup.dishes: '菜品',
                      _PhotoGroup.environment: '环境',
                    },
                    selected: _group,
                    onChanged: (group) => setState(() => _group = group),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
