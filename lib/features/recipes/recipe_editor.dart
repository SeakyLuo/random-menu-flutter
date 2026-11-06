import '../../ui/tag_selection_field.dart';
import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../media/media_actions.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import 'recipe_dialogs.dart';
import 'recipe_search.dart';
import 'recipe_editor_fields.dart';

Future<bool> editRecipe(
  BuildContext context, {
  Recipe? recipe,
  String? initialName,
  String? wantedName,
  bool fromDraft = false,
}) async {
  final editor = _RecipeEditor(
    recipe: recipe,
    initialName: initialName,
    wantedName: wantedName,
    fromDraft: fromDraft,
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

  Recipe _snapshot() => Recipe(
    id: widget.recipe?.id ?? newId(),
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
        builder: (context) => AlertDialog(
          title: const Text('保存这次编辑？'),
          content: const Text('可以存为草稿，下次接着编辑。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('放弃修改'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'draft'),
              child: const Text('保存草稿'),
            ),
          ],
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
          () => store.update((data) {
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

  Future<void> _photoAction(int index, String action) async {
    if (action == 'replace' || action == 'replaceCamera') {
      setState(() => _picking = true);
      final paths = await choosePhotos(
        context,
        camera: action == 'replaceCamera',
        single: true,
      );
      if (!mounted) return;
      setState(() {
        if (paths.isNotEmpty) _images[0] = paths.first;
        _picking = false;
      });
    } else if (action == 'cover') {
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
    setState(() => _saving = true);
    final success = await performAction(
      context,
      () => store.update((draft) {
        final recipe = _snapshot()..tags = tags.toList();
        if (widget.fromDraft &&
            draft.recipeDraftSourceId != null &&
            !draft.recipes.any((r) => r.id == draft.recipeDraftSourceId)) {
          recipe.id = newId();
        }
        if (duplicate != null) {
          final target = draft.recipes.firstWhere((r) => r.id == duplicate.id);
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
            draft.recipes[index] = recipe;
          }
          if (widget.fromDraft || draft.recipeDraftSourceId == recipe.id) {
            draft.recipeDraft = null;
            draft.recipeDraftSourceId = null;
          }
        }
        draft.recipeTags = {...draft.recipeTags, ...tags}.toList();
        if (widget.wantedName != null) draft.toCook.remove(widget.wantedName);
      }),
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
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
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
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton(
                onPressed: busy ? null : _save,
                child: Text(
                  _saving ? '正在保存…' : '保存菜谱',
                  style: const TextStyle(fontSize: 16),
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
                const RecipeFieldLabel('菜名', hint: '必填'),
                TextField(
                  controller: _name,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    hintText: '例如：番茄炒蛋',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                RecipePhotoFields(
                  paths: _images,
                  busy: busy,
                  onPick: (camera) => _pickImages(camera: camera),
                  onAction: _photoAction,
                ),
                const SizedBox(height: 24),
                TagSelectionField(
                  selected: _selectedTags,
                  choices: orderedRecipeTags(MenuScope.of(context).data),
                  busy: busy,
                  onChanged: (tags) => _tags.text = tags.join('，'),
                ),
                const SizedBox(height: 24),
                const RecipeFieldLabel('备注', hint: '可选'),
                TextField(
                  controller: _note,
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
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const MenuIcon(Icons.favorite_border, size: 22),
                  title: const Text('收藏这道菜', style: TextStyle(fontSize: 15)),
                  value: _favorite,
                  onChanged: busy ? null : (v) => setState(() => _favorite = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
