import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/menu_store.dart';
import '../../ui/favorite_glass_button.dart';
import '../../ui/library_widgets.dart';
import '../../ui/glass_surface.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../media/photo_viewer.dart';
import '../media/photo_widget.dart';
import 'restaurant_detail_page.dart';
import 'restaurant_editor.dart';
import 'restaurant_gallery_data.dart';
import 'restaurant_photo_deck.dart';

class RestaurantCard extends StatefulWidget {
  const RestaurantCard({super.key, required this.restaurant});
  final Restaurant restaurant;
  @override
  State<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard> {
  late List<RestaurantPhoto> _photos = restaurantGallery(widget.restaurant);
  bool _initialized = false;
  bool _savingFavorite = false;
  String? _selected;
  int get _index =>
      _selected == null ? 0 : _photos.indexWhere((p) => p.key == _selected);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _selected =
          PageStorage.of(context).readState(
                context,
                identifier: 'restaurant-photo:${widget.restaurant.id}',
              )
              as String?;
      if (_selected != null && !_photos.any((p) => p.key == _selected)) {
        _selected = null;
      }
      _initialized = true;
    }
  }

  void _select(int index) {
    setState(() => _selected = _photos[index].key);
    PageStorage.of(context).writeState(
      context,
      _selected,
      identifier: 'restaurant-photo:${widget.restaurant.id}',
    );
  }

  @override
  void didUpdateWidget(covariant RestaurantCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurant != widget.restaurant) {
      _photos = restaurantGallery(widget.restaurant);
      if (_selected != null && !_photos.any((p) => p.key == _selected)) {
        _selected = null;
      }
    }
  }

  Future<void> _unfavorite() async {
    setState(() => _savingFavorite = true);
    await performAction(
      context,
      () => MenuScope.of(context).update(
        (data) =>
            data.restaurants
                    .firstWhere((r) => r.id == widget.restaurant.id)
                    .favorite =
                false,
      ),
      success: '已取消收藏',
    );
    if (mounted) setState(() => _savingFavorite = false);
  }

  void _open() => showMenuDetail<void>(
    context,
    RestaurantDetailPage(restaurantId: widget.restaurant.id),
  );
  Future<void> _gallery() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoViewer(
          paths: _photos.map((p) => p.path).toList(),
          initial: _index,
          title: widget.restaurant.name,
          captions: _photos
              .map((photo) => PhotoCaption(name: photo.name, note: photo.note))
              .toList(),
          onPageChanged: _select,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final scheme = Theme.of(context).colorScheme;
    final count = r.addressEntries.isEmpty
        ? r.addresses.length
        : r.addressEntries.length;
    return GestureDetector(
      onLongPress: () => editRestaurant(context, restaurant: r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (_photos.isEmpty)
                _cover(context, 0)
              else
                RestaurantPhotoDeck(
                  // Recreate the motion state when gallery contents change.
                  key: ValueKey(
                    Object.hashAll(_photos.map((photo) => photo.key)),
                  ),
                  itemCount: _photos.length,
                  index: _index,
                  onChanged: _select,
                  onTap: _gallery,
                  itemBuilder: (context, index) => _cover(context, index),
                ),
              if (r.favorite)
                Positioned(
                  top: 13,
                  right: 13,
                  child: FavoriteGlassButton(
                    tooltip: '取消收藏${r.name}',
                    onPressed: _savingFavorite ? null : _unfavorite,
                  ),
                ),
            ],
          ),
          InkWell(
            onTap: _open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 7, 3, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${restaurantDisplayAddress(r)}${count > 1 ? ' 等 $count 家' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    r.averageCost > 0 ? '人均 ¥${money(r.averageCost)}' : '未记录人均',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  MenuIcon(
                    Icons.chevron_right,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover(BuildContext context, int index) {
    final r = widget.restaurant;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
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
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: _photos.isEmpty ? 128 : null,
              child: _photos.isEmpty
                  ? InkWell(
                      onTap: _open,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary.withValues(alpha: .1),
                              scheme.surfaceContainerLow,
                            ],
                          ),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.all(20),
                        child: MenuIcon(
                          Icons.storefront_outlined,
                          size: 36,
                          color: scheme.primary,
                        ),
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: 1.65,
                      child: RetainedLocalPhoto(path: _photos[index].path),
                    ),
            ),
          ),
          if (_photos.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22000000),
                        Colors.transparent,
                        Color(0x22000000),
                        Color(0xbb000000),
                      ],
                      stops: [0, .35, .55, 1],
                    ),
                  ),
                ),
              ),
            ),
          if (r.category.isNotEmpty)
            Positioned(
              left: 13,
              right: r.favorite ? 55 : 13,
              top: 13,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GlassSurface(
                    radius: 20,
                    blurSigma: _photos.isEmpty ? 0 : 24,
                    color: _photos.isEmpty
                        ? scheme.surface
                        : const Color(0x25ffffff),
                    borderColor: _photos.isEmpty
                        ? scheme.outlineVariant
                        : const Color(0x48ffffff),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      child: Text(
                        r.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: _photos.isEmpty
                              ? scheme.primary
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: _photos.isEmpty ? 65 : 16,
            bottom: 17,
            child: IgnorePointer(
              child: Text(
                r.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _photos.isEmpty ? 18 : 19,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: _photos.isEmpty ? scheme.onSurface : Colors.white,
                ),
              ),
            ),
          ),
          if (_photos.length > 1)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: dark ? const Color(0x1fffffff) : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
