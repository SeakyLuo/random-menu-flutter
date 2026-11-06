import 'dart:math' as math;
import '../../ui/menu_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_tag_colors.dart';
import '../../ui/widgets.dart';
import 'recipe_editor.dart';
import 'recipe_photos.dart';

enum _RecipeAction { favorite, hide }

Future<void> showRecipeDetail(BuildContext context, String id) =>
    showMenuBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      sheetAnimationStyle: AnimationStyle(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 240,
        ),
        reverseDuration: const Duration(milliseconds: 120),
      ),
      builder: (_) => RecipeDetailPage(recipeId: id),
    );

class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key, required this.recipeId});
  final String recipeId;
  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  bool _saving = false;
  int _photo = 0;
  String? _selectedPath;
  final _photos = PageController(keepPage: false);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final recipe = MenuScope.of(
      context,
    ).data.recipes.where((r) => r.id == widget.recipeId).firstOrNull;
    if (recipe == null) return;
    _photo = _selectedPath == null || !recipe.imagePaths.contains(_selectedPath)
        ? 0
        : recipe.imagePaths.indexOf(_selectedPath!);
    _selectedPath = recipe.imagePaths.isEmpty
        ? null
        : recipe.imagePaths[_photo];
    if (_photos.hasClients && recipe.imagePaths.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _photos.hasClients) _photos.jumpToPage(_photo);
      });
    }
  }

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  Future<void> _copyName(String name) => performAction(
    context,
    () => Clipboard.setData(ClipboardData(text: name)),
    success: '菜名已复制',
  );

  Future<void> _action(_RecipeAction action, Recipe recipe) async {
    final store = MenuScope.of(context);
    setState(() => _saving = true);
    await performAction(
      context,
      () => store.update((data) {
        final item = data.recipes.firstWhere((item) => item.id == recipe.id);
        switch (action) {
          case _RecipeAction.favorite:
            item.favorite = !item.favorite;
          case _RecipeAction.hide:
            item.hiddenRounds = item.hiddenRounds > 0 ? 0 : 3;
        }
      }),
      success: action == _RecipeAction.hide
          ? recipe.hiddenRounds > 0
                ? '已恢复抽取'
                : '最近3轮不再出现'
          : null,
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = MenuScope.of(
      context,
    ).data.recipes.where((r) => r.id == widget.recipeId).firstOrNull;
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('菜谱')),
        body: EmptyState(
          icon: Icons.menu_book_outlined,
          title: '这道菜谱已移除',
          message: '返回菜谱库，看看其他拿手菜。',
          actionLabel: '返回菜谱库',
          onAction: () => Navigator.pop(context),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final tagColors = MenuTagColors.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '菜谱详情',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: recipe.hiddenRounds > 0 ? '恢复随机推荐' : '最近3轮不出现',
                    onPressed: _saving
                        ? null
                        : () => _action(_RecipeAction.hide, recipe),
                    icon: MenuIcon(
                      recipe.hiddenRounds > 0
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: recipe.hiddenRounds > 0
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const MenuIcon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: recipe.imagePaths.isEmpty
                            ? 140
                            : math.min(260, constraints.maxWidth / 1.6),
                        child: recipe.imagePaths.isEmpty
                            ? ColoredBox(
                                color: scheme.primary.withValues(alpha: .08),
                                child: Center(
                                  child: MenuIcon(
                                    Icons.ramen_dining_outlined,
                                    size: 64,
                                    color: scheme.primary,
                                  ),
                                ),
                              )
                            : PageView.builder(
                                controller: _photos,
                                itemCount: recipe.imagePaths.length,
                                onPageChanged: (index) => setState(() {
                                  _photo = index;
                                  _selectedPath = recipe.imagePaths[index];
                                }),
                                itemBuilder: (_, index) => Semantics(
                                  label: '查看${recipe.name}照片 ${index + 1}',
                                  button: true,
                                  child: GestureDetector(
                                    onTap: () => showRecipePhotos(
                                      context,
                                      recipe.imagePaths,
                                      index,
                                      onPageChanged: (next) {
                                        setState(() {
                                          _photo = next;
                                          _selectedPath =
                                              recipe.imagePaths[next];
                                        });
                                        _photos.jumpToPage(next);
                                      },
                                    ),
                                    child: RecipePhoto(
                                      path: recipe.imagePaths[index],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    hint: '长按复制菜名',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => _copyName(recipe.name),
                      child: Text(
                        recipe.name,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (recipe.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in recipe.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: tagColors.background,
                              border: Border.all(color: tagColors.border),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: tagColors.foreground,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (recipe.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SelectableText(
                        recipe.note,
                        style: const TextStyle(fontSize: 14, height: 1.7),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '添加于 ${dayLabel(recipe.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (recipe.hiddenRounds > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '暂时不参与抽取 · 剩余 ${recipe.hiddenRounds} 轮',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: Row(
                spacing: 10,
                children: [
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton(
                      tooltip: recipe.favorite ? '取消收藏' : '收藏',
                      isSelected: recipe.favorite,
                      onPressed: _saving
                          ? null
                          : () => _action(_RecipeAction.favorite, recipe),
                      icon: MenuIcon(
                        recipe.favorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 23,
                        color: recipe.favorite
                            ? const Color(0xffef4762)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () => editRecipe(context, recipe: recipe),
                      icon: const MenuIcon(Icons.edit_outlined, size: 19),
                      label: const Text('编辑菜谱', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
