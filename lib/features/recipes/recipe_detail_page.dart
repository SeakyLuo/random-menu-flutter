import '../../ui/menu_popup.dart';
import 'dart:math' as math;
import '../../ui/hero_sheet_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/photo_page_indicator.dart';
import '../../ui/menu_tag_colors.dart';
import '../../ui/widgets.dart';
import 'recipe_editor.dart';
import 'recipe_photos.dart';
import 'recipe_tag_sheet.dart';
import 'recipe_share_page.dart';

enum _RecipeAction { favorite, hide }

Future<void> showRecipeDetail(BuildContext context, String id) =>
    showHeroSheet<void>(
      context: context,
      constraints: BoxConstraints(
        maxWidth: 560,
        maxHeight: MediaQuery.sizeOf(context).height * .88,
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
  late String _recipeId = widget.recipeId;
  final _scroll = ScrollController();
  final _savingActions = <(String, _RecipeAction)>{};
  int _photo = 0;
  String? _selectedPath;
  final _photos = PageController(keepPage: false);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final recipe = MenuScope.of(
      context,
    ).data.recipes.where((r) => r.id == _recipeId).firstOrNull;
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
    _scroll.dispose();
    _photos.dispose();
    super.dispose();
  }

  Future<void> _openTag(String tag) async {
    final id = await showRecipeTagSheet(context, tag);
    if (!mounted || id == null || id == _recipeId) return;
    setState(() {
      _recipeId = id;
      _photo = 0;
      _selectedPath = null;
    });
    _scroll.jumpTo(0);
  }

  Future<void> _copyName(String name) => performAction(
    context,
    () => Clipboard.setData(ClipboardData(text: name)),
    success: '菜名已复制',
  );

  Future<void> _action(_RecipeAction action, Recipe recipe) async {
    final store = MenuScope.of(context);
    setState(() => _savingActions.add((recipe.id, action)));
    await performAction(
      context,
      () => store.update(MenuWriteScope.recipe(recipe.id), (data) {
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
    if (mounted) setState(() => _savingActions.remove((recipe.id, action)));
  }

  @override
  Widget build(BuildContext context) {
    final recipe = MenuScope.of(
      context,
    ).data.recipes.where((r) => r.id == _recipeId).firstOrNull;
    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(
          title: MenuScrollTitle(controller: _scroll, child: const Text('菜谱')),
        ),
        body: EmptyState(
          icon: Icons.edit_note,
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
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: MenuScrollTitle(
                      controller: _scroll,
                      child: Text(
                        '菜谱详情',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '编辑菜谱',
                    onPressed: () => editRecipe(context, recipe: recipe),
                    icon: const MenuIcon(Icons.edit_outlined, size: 23),
                  ),
                  IconButton(
                    tooltip: recipe.favorite ? '取消喜欢' : '我喜欢',
                    isSelected: recipe.favorite,
                    onPressed:
                        _savingActions.contains((
                          recipe.id,
                          _RecipeAction.favorite,
                        ))
                        ? null
                        : () => _action(_RecipeAction.favorite, recipe),
                    icon: MenuIcon(
                      recipe.favorite ? Icons.favorite : Icons.favorite_border,
                      size: 23,
                      color: recipe.favorite
                          ? const Color(0xffef4762)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  MenuPopupButton<String>(
                    tooltip: '更多',
                    icon: const MenuIcon(Icons.more_horiz),
                    onSelected: (action) {
                      if (action == 'share') {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => RecipeSharePage(
                              recipe: recipe,
                              coverPath: _selectedPath,
                            ),
                          ),
                        );
                      } else {
                        _action(_RecipeAction.hide, recipe);
                      }
                    },
                    itemBuilder: (_) => [
                      const MenuPopupItem(
                        icon: Icons.ios_share_rounded,
                        value: 'share',
                        child: Text('分享菜谱'),
                      ),
                      MenuPopupItem(
                        icon: recipe.hiddenRounds > 0
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        value: 'hide',
                        enabled: !_savingActions.contains((
                          recipe.id,
                          _RecipeAction.hide,
                        )),
                        child: Text(
                          recipe.hiddenRounds > 0
                              ? '恢复抽取（剩余${recipe.hiddenRounds}轮）'
                              : '最近3轮不出现',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: ListView(
                controller: _scroll,
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            recipe.imagePaths.isEmpty
                                ? ColoredBox(
                                    color: scheme.primary.withValues(
                                      alpha: .08,
                                    ),
                                    child: Center(
                                      child: MenuIcon(
                                        Icons.ramen_dining_outlined,
                                        size: 64,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  )
                                : PageView.builder(
                                    key: ValueKey(recipe.id),
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
                                          heroTagForIndex: (i) =>
                                              (this, recipe.id, i),
                                          onReturnIndex: (next) {
                                            setState(() {
                                              _photo = next;
                                              _selectedPath =
                                                  recipe.imagePaths[next];
                                            });
                                            _photos.jumpToPage(next);
                                          },
                                        ),
                                        child: Hero(
                                          tag: (this, recipe.id, index),
                                          child: RecipePhoto(
                                            path: recipe.imagePaths[index],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            if (recipe.imagePaths.length > 1)
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: PhotoPageIndicator(
                                  index: _photo,
                                  count: recipe.imagePaths.length,
                                ),
                              ),
                          ],
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
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openTag(tag),
                            child: Semantics(
                              button: true,
                              label: '查看$tag菜谱',
                              child: Container(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
