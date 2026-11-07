import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/favorite_glass_button.dart';
import '../../ui/menu_icon.dart';
import '../media/photo_widget.dart';

class RandomRecipeCard extends StatelessWidget {
  const RandomRecipeCard({
    super.key,
    required this.recipe,
    this.captionOpacity = 1,
    this.onOpen,
    this.onFavorite,
    this.onLongPress,
    this.compact = false,
    this.coverPath,
    this.showFavorite = true,
    this.titleSpan,
  });
  final Recipe recipe;
  final double captionOpacity;
  final VoidCallback? onOpen;
  final VoidCallback? onFavorite;
  final VoidCallback? onLongPress;
  final bool compact;
  final String? coverPath;
  final bool showFavorite;
  final InlineSpan? titleSpan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = coverPath != null || recipe.imagePaths.isNotEmpty;
    final caption = Opacity(
      opacity: captionOpacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            titleSpan ?? TextSpan(text: recipe.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 16 : 25,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: hasPhoto ? Colors.white : scheme.onSurface,
            ),
          ),
          if (compact && recipe.hiddenRounds > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '暂时不参与抽取',
                style: TextStyle(
                  fontSize: 11,
                  color: hasPhoto
                      ? Colors.white.withValues(alpha: .85)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Color(compact ? 0x10172c21 : 0x1a172c21),
            blurRadius: compact ? 14 : 24,
            offset: Offset(0, compact ? 4 : 10),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(dark ? 1 : 2),
        decoration: BoxDecoration(
          color: dark ? const Color(0x1fffffff) : scheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dark ? 21 : 20),
          child: Stack(
            fit: compact ? StackFit.loose : StackFit.expand,
            children: [
              Positioned.fill(
                child: RecipeCover(recipe: recipe, path: coverPath),
              ),
              if (hasPhoto)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0, -.1),
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x40000000),
                          Color(0xb3000000),
                          Color(0xd6000000),
                        ],
                        stops: [0, .35, .75, 1],
                      ),
                    ),
                  ),
                ),
              if (compact)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AspectRatio(aspectRatio: 1, child: SizedBox.expand()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: caption,
                    ),
                  ],
                )
              else
                Positioned(left: 16, right: 16, bottom: 18, child: caption),
              if (onOpen != null || onLongPress != null)
                Positioned.fill(
                  child: Semantics(
                    button: true,
                    label: '查看${recipe.name}详情',
                    child: GestureDetector(
                      onTap: onOpen,
                      onLongPress: onLongPress,
                      behavior: HitTestBehavior.opaque,
                    ),
                  ),
                ),
              if (showFavorite && recipe.favorite)
                Positioned(
                  top: compact ? 8 : 12,
                  right: compact ? 8 : 12,
                  child: FavoriteGlassButton(
                    size: compact ? 34 : 40,
                    iconSize: compact ? 21 : 23,
                    tooltip: '取消收藏${recipe.name}',
                    onPressed: onFavorite,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeCover extends StatelessWidget {
  const RecipeCover({super.key, required this.recipe, this.path});
  final Recipe recipe;
  final String? path;
  @override
  Widget build(BuildContext context) =>
      path != null || recipe.imagePaths.isNotEmpty
      ? RetainedLocalPhoto(path: path ?? recipe.imagePaths.first)
      : DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .4),
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: Center(
            child: MenuIcon(
              Icons.ramen_dining_outlined,
              size: 54,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .5),
            ),
          ),
        );
}
