import '../../ui/tag_selection_field.dart';
import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../ui/menu_dialog.dart';
import '../media/media_actions.dart';
import '../../core/menu_store.dart';
import '../../core/record_conflicts.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'recipe_dialogs.dart';
import 'recipe_search.dart';
import 'recipe_editor_fields.dart';
import 'recipe_photos.dart';
import '../media/photo_edit_actions.dart';

Future<bool> editRecipe(
  BuildContext context, {
  Recipe? recipe,
  String? initialName,
  String? wantedName,
  bool fromDraft = false,
}) async {
  var editingRecipe = recipe;
  var editingDraft = fromDraft;
  final draft = MenuScope.of(context).data.recipeDraft;
  if (recipe == null && !fromDraft && draft != null) {
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => MenuDialog(
        title: '继续未完成的菜谱？',
        description:
            '${draft.name.isEmpty ? '之前保存了一份未命名草稿。' : '“${draft.name}”还没有完成。'}'
            '\n也可以新建菜谱，原草稿会保留。',
        actions: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuDialogButton(
              label: '继续编辑',
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            MenuDialogButton(
              label: '新建菜谱',
              role: MenuDialogRole.secondary,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (resume == null || !context.mounted) return false;
    if (resume) {
      editingRecipe = draft;
      editingDraft = true;
    }
  }
  final editor = _RecipeEditor(
    recipe: editingRecipe,
    initialName: initialName,
    wantedName: wantedName,
    fromDraft: editingDraft,
  );
  return await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(builder: (_) => editor),
      ) ==
      true;
}

class _RecipeEditor extends StatefulWidget {
  const _RecipeEditor({
    this.recipe,
    this.initialName,
    this.wantedName,
    required this.fromDraft,
  });
  final bool fromDraft;
  final Recipe? recipe;
  final String? initialName;
  final String? wantedName;
  @override
  State<_RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<_RecipeEditor> {
  late final _name = TextEditingController(
    text: widget.recipe?.name ?? widget.initialName ?? '',
  );
  late final _note = TextEditingController(text: widget.recipe?.note ?? '');
  late final _tags = TextEditingController(
    text: widget.recipe?.tags.join('，') ?? '',
  );
  late final List<String> _images = [...?widget.recipe?.imagePaths];
  late bool _favorite = widget.recipe?.favorite ?? false;
  late final _createdAt = widget.recipe?.createdAt ?? DateTime.now();
  bool _saving = false;
  bool _picking = false;
  bool _leaving = false;
  bool get _changed =>
      _name.text != (widget.recipe?.name ?? widget.initialName ?? '') ||
      _note.text != (widget.recipe?.note ?? '') ||
      _tags.text != (widget.recipe?.tags.join('，') ?? '') ||
      _favorite != (widget.recipe?.favorite ?? false) ||
      _images.join('\n') != (widget.recipe?.imagePaths.join('\n') ?? '');

  @override
  void initState() {
    super.initState();
    _name.addListener(_textChanged);
    _note.addListener(_textChanged);
    _tags.addListener(_textChanged);
  }

  void _textChanged() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _tags.dispose();
    super.dispose();
  }

  late final String _editingId = widget.recipe?.id ?? newId();

  Recipe _snapshot() => Recipe(
    id: _editingId,
    name: _name.text.trim(),
    note: _note.text.trim(),
    tags: _manualTags,
    imagePaths: [..._images],
    favorite: _favorite,
    hiddenRounds: widget.recipe?.hiddenRounds ?? 0,
    createdAt: _createdAt,
  );

  List<String> get _manualTags => _selectedTags;

  List<String> get _selectedTags => _tags.text
      .split(RegExp('[,，]'))
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _leave() async {
    if (_saving || _picking) return;
    if (_changed) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => MenuDialog(
          title: '保存这次编辑？',
          description: '可以存为草稿，下次接着编辑。',
          actions: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MenuDialogButton(
                label: '保存草稿',
                onPressed: () => Navigator.pop(context, 'draft'),
              ),
              const SizedBox(height: 10),
              MenuDialogButton(
                label: '放弃修改',
                role: MenuDialogRole.destructive,
                onPressed: () => Navigator.pop(context, 'discard'),
              ),
              const SizedBox(height: 10),
              MenuDialogButton(
                label: '继续编辑',
                role: MenuDialogRole.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'draft') {
        final store = MenuScope.of(context);
        if (store.data.recipeDraft != null && !widget.fromDraft) {
          if (!await confirmAction(
            context,
            title: '替换现有草稿？',
            message: '只能保存一份草稿，之前的草稿会被当前内容替换。',
            confirmLabel: '替换草稿',
          )) {
            return;
          }
          if (!mounted) return;
        }
        setState(() => _saving = true);
        final success = await performAction(
          context,
          () => store.update(MenuWriteScope.settings, (data) {
            data.recipeDraft = _snapshot();
            if (!widget.fromDraft) data.recipeDraftSourceId = widget.recipe?.id;
          }),
          success: '已保存草稿',
        );
        if (!mounted) return;
        if (!success) {
          setState(() => _saving = false);
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    Navigator.of(context).pop(false);
  }

  Future<void> _pickImages({bool camera = false}) async {
    setState(() => _picking = true);
    final paths = await choosePhotos(context, camera: camera);
    if (mounted) {
      setState(() {
        _images.addAll(paths);
        _picking = false;
      });
    }
  }

  Future<void> _delete() async {
    final recipe = widget.recipe!;
    if (!await confirmAction(
      context,
      title: '删除“${recipe.name}”？',
      message: '删除后无法恢复，已选菜单中的这道菜也会移除。',
      confirmLabel: '删除菜谱',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final deleted = await performAction(
      context,
      () => MenuScope.of(context).update(MenuWriteScope.recipe(recipe.id), (
        data,
      ) {
        data.recipes.removeWhere((item) => item.id == recipe.id);
        data.selectedMenu.removeWhere((id) => id == recipe.id);
        if (data.recipeDraftSourceId == recipe.id) {
          data.recipeDraft = null;
          data.recipeDraftSourceId = null;
        }
      }),
      success: '菜谱已删除',
    );
    if (!mounted) return;
    if (deleted) {
      setState(() => _leaving = true);
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  Future<void> _photoAction(int index, String action) async {
    if (action == 'cover') {
      setState(() {
        final path = _images.removeAt(index);
        _images.insert(0, path);
      });
    } else if (action == 'remove') {
      setState(() => _images.removeAt(index));
    } else {
      setState(() => _picking = true);
      final cropped = await cropPhoto(context, _images[index]);
      if (!mounted) return;
      setState(() {
        if (cropped != null) _images[index] = cropped;
        _picking = false;
      });
    }
  }

  Future<PhotoEditResult> _editPreviewPhoto(String path, String action) async {
    final index = _images.indexOf(path);
    await _photoAction(index, action);
    return PhotoEditResult(
      path: action == 'remove'
          ? null
          : action == 'cover'
          ? path
          : _images[index],
      coverPath: _images.isEmpty ? null : _images.first,
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, '请填写菜名');
      return;
    }
    final store = MenuScope.of(context);
    final tags = _manualTags.toSet();
    if (tags.isEmpty && store.data.autoTag) {
      setState(() => _saving = true);
      try {
        tags.addAll(await store.data.inferRecipeTags(name));
      } on FormatException catch (error) {
        if (mounted) showToast(context, error.message);
        return;
      } catch (error, stack) {
        debugPrint('Automatic recipe tagging failed: $error\n$stack');
        if (mounted) showToast(context, '自动标签匹配未完成，请重试');
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      if (!mounted) return;
    }
    if (tags.isEmpty || tags.length > 10) {
      showToast(context, tags.isEmpty ? '请添加至少1个标签' : '每道菜最多添加10个标签');
      return;
    }
    final duplicates = store.data.recipes.where(
      (r) => r.id != widget.recipe?.id && r.name == name,
    );
    final duplicate = duplicates.isEmpty ? null : duplicates.first;
    List<String>? mergedTags;
    if (duplicate != null) {
      final replacesSource =
          widget.recipe != null &&
          store.data.recipes.any((r) => r.id == widget.recipe!.id);
      if (!await confirmAction(
        context,
        title: '合并到已有的“$name”？',
        message:
            '保留已有菜谱的创建时间与封面，追加当前照片、标签和备注；任一菜谱已收藏则保留收藏。'
            '${replacesSource ? '当前编辑的菜谱会移除，本次菜单会自动更新。' : ''}',
        confirmLabel: '合并菜谱',
        destructive: false,
      )) {
        return;
      }
      if (!mounted) return;
      mergedTags = {...duplicate.tags, ...tags}.toList();
      if (mergedTags.length > 10) {
        mergedTags = await chooseMergeTags(context, mergedTags);
        if (mergedTags == null || !mounted) return;
      }
    }
    final savedId =
        widget.fromDraft &&
            store.data.recipeDraftSourceId != null &&
            !store.data.recipes.any(
              (r) => r.id == store.data.recipeDraftSourceId,
            )
        ? newId()
        : _editingId;
    setState(() => _saving = true);
    final success = await performAction(
      context,
      () => store.update(
        MenuWriteScope(
          recipeIds: {_editingId, savedId, if (duplicate != null) duplicate.id},
        ),
        (draft) {
          if (widget.recipe != null && !widget.fromDraft) {
            requireUnchangedRecord(
              widget.recipe!.toJson(),
              draft.recipes
                  .where((r) => r.id == widget.recipe!.id)
                  .firstOrNull
                  ?.toJson(),
              ignored: {
                'hiddenRounds',
                if (_favorite == widget.recipe!.favorite) 'favorite',
              },
            );
          }
          final recipe = _snapshot()..tags = tags.toList();
          if (widget.fromDraft &&
              draft.recipeDraftSourceId != null &&
              !draft.recipes.any((r) => r.id == draft.recipeDraftSourceId)) {
            recipe.id = savedId;
          }
          if (duplicate != null) {
            final target = draft.recipes.firstWhere(
              (r) => r.id == duplicate.id,
            );
            mergeRecipe(target, recipe);
            target.tags = mergedTags!;
            if (widget.recipe != null && widget.recipe!.id != target.id) {
              draft.recipes.removeWhere((r) => r.id == recipe.id);
              draft.selectedMenu = draft.selectedMenu
                  .map((id) => id == recipe.id ? target.id : id)
                  .toSet()
                  .toList();
            }
            if (draft.recipeDraft?.id == recipe.id || widget.fromDraft) {
              draft.recipeDraft = null;
              draft.recipeDraftSourceId = null;
            }
          } else {
            final index = draft.recipes.indexWhere((r) => r.id == recipe.id);
            if (index == -1) {
              draft.recipes.add(recipe);
            } else {
              if (!widget.fromDraft && _favorite == widget.recipe?.favorite) {
                recipe.favorite = draft.recipes[index].favorite;
              }
              recipe.hiddenRounds = draft.recipes[index].hiddenRounds;
              draft.recipes[index] = recipe;
            }
            if (widget.fromDraft || draft.recipeDraftSourceId == recipe.id) {
              draft.recipeDraft = null;
              draft.recipeDraftSourceId = null;
            }
          }
          draft.recipeTags = {...draft.recipeTags, ...tags}.toList();
          if (widget.wantedName != null) draft.toCook.remove(widget.wantedName);
        },
      ),
      success: '菜谱已保存',
    );
    if (!mounted) return;
    if (success) {
      setState(() => _leaving = true);
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _picking;
    return PopScope(
      canPop: _leaving || (!_changed && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(
            widget.fromDraft
                ? '编辑草稿'
                : widget.recipe == null
                ? '添加菜谱'
                : '编辑菜谱',
          ),
          leading: IconButton(
            tooltip: '返回',
            onPressed: busy ? null : _leave,
            icon: const MenuIcon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: _favorite ? '取消收藏' : '收藏',
              isSelected: _favorite,
              onPressed: busy
                  ? null
                  : () => setState(() => _favorite = !_favorite),
              icon: MenuIcon(
                _favorite ? Icons.favorite : Icons.favorite_border,
                size: 23,
                color: _favorite
                    ? const Color(0xffef4762)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.recipe != null && !widget.fromDraft)
              IconButton(
                tooltip: '删除菜谱',
                onPressed: busy ? null : _delete,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                icon: const MenuIcon(Icons.delete_outline, size: 22),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : _save,
                    child: Text(
                      _saving ? '正在保存…' : '保存菜谱',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                const MenuFieldLabel('菜名', isRequired: true),
                TextField(
                  controller: _name,
                  style: const TextStyle(fontSize: 15),
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    hintText: '例如：番茄炒蛋',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                EditorPhotoFields(
                  paths: _images,
                  busy: busy,
                  onPick: (camera) => _pickImages(camera: camera),
                  onAction: _photoAction,
                  onReorder: (from, to) => setState(() {
                    final path = _images.removeAt(from);
                    _images.insert(to, path);
                  }),
                  onOpen: (index) => showRecipePhotos(
                    context,
                    _images,
                    index,
                    onEdit: _editPreviewPhoto,
                  ),
                ),
                const SizedBox(height: 24),
                TagSelectionField(
                  selected: _selectedTags,
                  choices: orderedRecipeTags(MenuScope.of(context).data),
                  busy: busy,
                  onChanged: (tags) => _tags.text = tags.join('，'),
                ),
                const SizedBox(height: 24),
                const MenuFieldLabel('备注'),
                TextField(
                  controller: _note,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                  enabled: !busy,
                  minLines: 3,
                  maxLines: 12,
                  maxLength: 10000,
                  decoration: const InputDecoration(
                    hintText: '记下用料、做法或小贴士…',
                    counterText: '',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
