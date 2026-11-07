import 'package:flutter/material.dart';
import '../../ui/menu_icon.dart';
import '../../ui/search_match.dart';
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
                  text: '“${searchMatchExcerpt(note, query)}”',
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
