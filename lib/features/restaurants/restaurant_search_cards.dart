import 'package:flutter/material.dart';
import '../../ui/menu_icon.dart';
import '../../ui/library_photo_card.dart';
import '../../ui/search_match.dart';
import '../media/photo_widget.dart';
import 'restaurant_search_fields.dart';
import 'restaurant_food_summary.dart';
import '../../ui/widgets.dart';

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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LibraryPhotoCard(
                hasPhoto: hasPhoto,
                label: '查看${dish.name}详情',
                onTap: onOpen,
                cover: hasPhoto
                    ? RetainedLocalPhoto(path: dish.paths.first)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primaryContainer.withValues(alpha: .4),
                              scheme.surface,
                            ],
                          ),
                        ),
                        child: Center(
                          child: MenuIcon(
                            Icons.ramen_dining_outlined,
                            size: 54,
                            color: scheme.primary.withValues(alpha: .5),
                          ),
                        ),
                      ),
                caption: Text.rich(
                  highlightSearchText(
                    dish.name.isEmpty ? '未命名菜品' : dish.name,
                    query,
                    hasPhoto ? const Color(0xff83d8ac) : scheme.primary,
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
                )
              else if (dish.note.isEmpty &&
                  (dish.package != null || dish.price > 0))
                SearchMatchCaption(
                  text: dish.package != null
                      ? visitPackageLabel(dish.package!)
                      : '¥${money(dish.price)}',
                  query: '',
                  onTap: onOpen,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
