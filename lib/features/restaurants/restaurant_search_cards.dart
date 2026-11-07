import 'package:flutter/material.dart';
import '../../ui/menu_icon.dart';
import '../../ui/search_match.dart';
import '../../ui/widgets.dart';
import '../media/photo_widget.dart';
import 'restaurant_search_fields.dart';

class SearchDishCard extends StatelessWidget {
  const SearchDishCard({
    super.key,
    required this.hit,
    required this.query,
    required this.onOpen,
  });
  final RestaurantDishHit hit;
  final String query;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dish = hit.dish;
    final hasPhoto = dish.paths.isNotEmpty;
    return Semantics(
      button: true,
      label: '查看${dish.name}详情',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasPhoto)
                        RetainedLocalPhoto(path: dish.paths.first)
                      else
                        ColoredBox(
                          color: scheme.surfaceContainer,
                          child: Center(
                            child: MenuIcon(
                              Icons.ramen_dining_outlined,
                              size: 36,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (hasPhoto)
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Color(0xc4000000),
                              ],
                              stops: [0, .45, 1],
                            ),
                          ),
                        ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Text.rich(
                          highlightSearchText(
                            dish.name,
                            query,
                            hasPhoto ? const Color(0xffffe4a3) : scheme.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: hasPhoto ? Colors.white : scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 7, 3, 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: MenuIcon(
                        Icons.storefront,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text.rich(
                        highlightSearchText(
                          hit.restaurant.name,
                          query,
                          scheme.primary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hit.note case final note?)
                SearchMatchCaption(
                  text: searchMatchExcerpt(note, query),
                  query: query,
                  onTap: onOpen,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchReviewCard extends StatelessWidget {
  const SearchReviewCard({
    super.key,
    required this.hit,
    required this.query,
    required this.onOpen,
    this.showPhotos = true,
  });
  final RestaurantReviewHit hit;
  final String query;
  final VoidCallback onOpen;
  final bool showPhotos;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark
          ? scheme.surfaceContainerLow
          : Colors.white.withValues(alpha: .75),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      highlightSearchText(
                        hit.restaurant.name,
                        query,
                        scheme.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MenuIcon(
                    Icons.chevron_right,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${hit.visit == null ? '' : '${dayLabel(hit.visit!.date).replaceAll('-', '.')} · '}${hit.source}',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                highlightSearchText(
                  searchMatchExcerpt(hit.text, query),
                  query,
                  scheme.primary,
                  backgroundColor: scheme.primary.withValues(alpha: .1),
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: scheme.onSurface,
                ),
              ),
              if (showPhotos && hit.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final path in hit.photos.take(2))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 88,
                            height: 64,
                            child: RetainedLocalPhoto(path: path),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
