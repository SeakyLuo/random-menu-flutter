import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../media/photo_widget.dart';

class RandomRecipeCard extends StatelessWidget {
  const RandomRecipeCard({
    super.key,
    required this.recipe,
    required this.busy,
    required this.menuCount,
    required this.onOpen,
    required this.onSelect,
    required this.onSkip,
    required this.onReshuffle,
  });
  final Recipe recipe;
  final bool busy;
  final int menuCount;
  final VoidCallback onOpen;
  final VoidCallback onSelect;
  final VoidCallback onSkip;
  final VoidCallback onReshuffle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final canSwipeVertically =
          constraints.maxHeight >= 650 &&
          MediaQuery.textScalerOf(context).scale(14) <= 18.2;
      final height = canSwipeVertically
          ? constraints.maxHeight - 120
          : 650 *
                (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1, 1.6);
      final content = SizedBox(
        height: height.toDouble(),
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .96, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: GestureDetector(
                  key: ValueKey(recipe.id),
                  onHorizontalDragEnd: busy
                      ? null
                      : (details) {
                          if (details.primaryVelocity! > 350) onReshuffle();
                        },
                  onVerticalDragEnd: !canSwipeVertically || busy
                      ? null
                      : (details) {
                          if (details.primaryVelocity! < -350) onSelect();
                          if (details.primaryVelocity! > 350) onSkip();
                        },
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: busy ? null : onOpen,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 5,
                            child: recipe.imagePaths.isNotEmpty
                                ? LocalPhoto(path: recipe.imagePaths.first)
                                : Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: .6),
                                          Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerLow,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: MenuIcon(
                                        Icons.ramen_dining_outlined,
                                        size: 80,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: .7),
                                      ),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '今日灵感',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 12,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  recipe.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (recipe.tags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    recipe.tags
                                        .map((tag) => '#$tag')
                                        .join('  '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                                if (recipe.note.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    recipe.note,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Text(
                                  '查看完整菜谱  →',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onSkip,
                    icon: const MenuIcon(Icons.skip_next_rounded),
                    label: const Text('这次跳过'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onSelect,
                    icon: const MenuIcon(Icons.add_rounded),
                    label: const Text('加入菜单'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              canSwipeVertically
                  ? '上滑加入 · 下滑跳过 · 右滑再抽一轮'
                  : '已选 $menuCount 道 · 右滑再抽一轮',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 490),
          child: canSwipeVertically
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 116),
                  child: content,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                  child: content,
                ),
        ),
      );
    },
  );
}
