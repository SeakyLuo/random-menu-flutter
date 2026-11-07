import 'package:flutter/material.dart';
import '../../ui/search_scope.dart';
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
    } else if (oldWidget.environmentPaths.isEmpty && widget.dishPaths.isEmpty) {
      _group = _PhotoGroup.environment;
    }
  }

  void _open(List<String> paths, int index) {
    final group = _group;
    showPhotoViewer(
      context,
      paths,
      index,
      title: group == _PhotoGroup.environment ? '用餐环境' : widget.name,
      onReturnIndex: (next) {
        if (mounted) setState(() => _selectedPaths[group] = paths[next]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final paths = _group == _PhotoGroup.dishes
        ? widget.dishPaths
        : widget.environmentPaths;
    final selectedIndex = paths.indexOf(_selectedPaths[_group] ?? '');
    final index = selectedIndex < 0 ? 0 : selectedIndex;
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
              onChanged: (next) =>
                  setState(() => _selectedPaths[_group] = paths[next]),
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
            )
          else if (widget.environmentPaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '还没有菜品照片',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          if (widget.environmentPaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: SearchScope<_PhotoGroup>(
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
