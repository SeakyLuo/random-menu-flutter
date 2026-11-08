import 'restaurant_price.dart';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/menu_store.dart';
import '../../ui/favorite_glass_button.dart';
import '../../ui/glass_surface.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import '../../ui/search_match.dart';
import '../media/photo_widget.dart';
import 'restaurant_detail_page.dart';
import 'restaurant_gallery_data.dart';
import 'restaurant_photo_deck.dart';
import 'restaurant_distance.dart';

class RestaurantCard extends StatefulWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.distance,
    this.showDistance = false,
    this.showReview = false,
    this.onOpen,
    this.titleBuilder,
  });
  final RestaurantDistance? distance;
  final bool showDistance;
  final bool showReview;
  final Restaurant restaurant;
  final VoidCallback? onOpen;
  final InlineSpan Function(bool hasPhoto)? titleBuilder;
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
        MenuWriteScope.restaurant(widget.restaurant.id),
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

  void _open() {
    if (widget.onOpen case final onOpen?) {
      onOpen();
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            RestaurantDetailPage(restaurantId: widget.restaurant.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    var review = r.note.trim();
    if (widget.showReview && review.isEmpty) {
      Visit? latestReview;
      for (final visit in r.records) {
        if (visit.note.trim().isNotEmpty &&
            (latestReview == null || visit.date.isAfter(latestReview.date))) {
          latestReview = visit;
        }
      }
      review = latestReview?.note.trim() ?? '';
    }
    final scheme = Theme.of(context).colorScheme;
    final count = r.addressEntries.isEmpty
        ? r.addresses.length
        : r.addressEntries.length;
    return GestureDetector(
      onTap: _open,
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
                  onTap: _open,
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
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(3, 5, 3, 5),
                child: Row(
                  children: [
                    MenuIcon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${widget.showDistance ? '${widget.distance?.label ?? '位置待补充'} · ' : ''}${restaurantDisplayAddress(r, address: widget.distance?.address)}${count > 1 ? ' 等 $count 家' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (r.averageCost > 0)
                      RestaurantPrice(r.averageCost)
                    else
                      Text(
                        '未记录人均',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.showReview && review.isNotEmpty)
            SearchMatchCaption(
              text: '“$review”',
              query: '',
              onTap: _open,
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
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
        color: scheme.surface,
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
              child: Text.rich(
                widget.titleBuilder?.call(_photos.isNotEmpty) ??
                    TextSpan(text: r.name),
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
