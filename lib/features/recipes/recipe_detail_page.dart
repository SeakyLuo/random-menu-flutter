import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'recipe_editor.dart';
import 'recipe_photos.dart';

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key, required this.recipeId});
  final String recipeId;

  Future<void> _delete(BuildContext context, Recipe recipe) async {
    final store = MenuScope.of(context);
    if (!await confirmAction(
      context,
      title: '删除“${recipe.name}”？',
      message: '删除后无法恢复，也会从本次菜单中移除。',
    )) {
      return;
    }
    if (!context.mounted) return;
    final success = await performAction(
      context,
      () => store.update((draft) {
        draft.recipes.removeWhere((r) => r.id == recipeId);
        draft.selectedMenu.remove(recipeId);
      }),
      success: '菜谱已删除',
    );
    if (success && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = MenuScope.of(context);
    final matches = store.data.recipes.where((r) => r.id == recipeId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('菜谱')),
        body: EmptyState(
          icon: Icons.menu_book_outlined,
          title: '这道菜谱已移除',
          message: '返回菜谱库，看看其他拿手菜。',
          actionLabel: '返回菜谱库',
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    }
    final recipe = matches.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('菜谱详情'),
        actions: [
          IconButton(
            tooltip: recipe.favorite ? '取消收藏' : '收藏',
            icon: MenuIcon(
              recipe.favorite ? Icons.favorite : Icons.favorite_border,
              color: recipe.favorite
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: () => performAction(
              context,
              () => store.update((draft) {
                final item = draft.recipes.firstWhere((r) => r.id == recipeId);
                item.favorite = !item.favorite;
              }),
              success: recipe.favorite ? '已取消收藏' : '已收藏',
            ),
          ),
          TextButton(
            onPressed: () => editRecipe(context, recipe: recipe),
            child: const Text('编辑'),
          ),
          PopupMenuButton<String>(
            icon: const MenuIcon(Icons.more_horiz),
            tooltip: '更多操作',
            onSelected: (action) async {
              if (action == 'delete') {
                await _delete(context, recipe);
                return;
              }
              if (action == 'copyName' || action == 'copyNote') {
                await performAction(
                  context,
                  () => Clipboard.setData(
                    ClipboardData(
                      text: action == 'copyName' ? recipe.name : recipe.note,
                    ),
                  ),
                  success: '已复制',
                );
                return;
              }
              final hidden = recipe.hiddenRounds > 0;
              await performAction(
                context,
                () => store.update((data) {
                  data.recipes
                      .firstWhere((r) => r.id == recipeId)
                      .hiddenRounds = hidden
                      ? 0
                      : 3;
                }),
                success: hidden ? '已恢复随机推荐' : '已隐藏3轮随机推荐',
              );
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'hide',
                child: Text(recipe.hiddenRounds > 0 ? '恢复随机推荐' : '隐藏3轮随机推荐'),
              ),
              const PopupMenuItem(value: 'copyName', child: Text('复制菜名')),
              if (recipe.note.isNotEmpty)
                const PopupMenuItem(value: 'copyNote', child: Text('复制做法与备注')),
              const PopupMenuItem(value: 'delete', child: Text('删除菜谱')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            children: [
              if (recipe.imagePaths.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => showRecipePhotos(context, recipe.imagePaths, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: RecipePhoto(path: recipe.imagePaths.first),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SelectableText(
                recipe.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '创建于 ${dayLabel(recipe.createdAt)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (recipe.hiddenRounds > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('暂不推荐 · 剩余 ${recipe.hiddenRounds} 轮'),
                      ),
                      TextButton(
                        onPressed: () => performAction(
                          context,
                          () => store.update((data) {
                            data.recipes
                                    .firstWhere((r) => r.id == recipeId)
                                    .hiddenRounds =
                                0;
                          }),
                          success: '已恢复随机推荐',
                        ),
                        child: const Text('恢复推荐'),
                      ),
                    ],
                  ),
                ),
              if (recipe.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in recipe.tags)
                      Chip(
                        label: Text(tag),
                        side: BorderSide.none,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: .45),
                      ),
                  ],
                ),
              ],
              const SectionTitle('做法与备注'),
              if (recipe.note.isNotEmpty)
                SelectableText(
                  recipe.note,
                  style: const TextStyle(fontSize: 16, height: 1.75),
                )
              else ...[
                Text(
                  '还没记录做法，下次做菜时可以随手记下来。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => editRecipe(context, recipe: recipe),
                    icon: const MenuIcon(Icons.edit_outlined),
                    label: const Text('补充做法'),
                  ),
                ),
              ],
              if (recipe.imagePaths.length > 1) ...[
                const SectionTitle('更多照片'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 1; i < recipe.imagePaths.length; i++)
                      GestureDetector(
                        onTap: () =>
                            showRecipePhotos(context, recipe.imagePaths, i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 140,
                            height: 140,
                            child: RecipePhoto(path: recipe.imagePaths[i]),
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
