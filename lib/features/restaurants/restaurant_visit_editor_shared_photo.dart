part of 'restaurant_visit_editor.dart';

extension _RestaurantVisitEditorSharedPhoto on _RestaurantVisitEditorState {
  Future<void> addSharedPhoto() async {
    final targets = await _selectPhotoDishes();
    if (targets == null || !mounted) return;

    final existing = visitPhotoPaths(items, images);
    String? path;
    if (existing.isNotEmpty) {
      final source = await showVisitPhotoPicker(
        context,
        existing,
        allowAlbum: true,
      );
      if (source == null || !mounted) return;
      path = source.path;
    }
    if (path == null) {
      updateForm(() => picking = true);
      final selected = await choosePhotos(context, single: true);
      if (!mounted) return;
      updateForm(() => picking = false);
      if (selected.isEmpty) return;
      path = selected.single;
    }

    final photoPath = path;
    final additions = targets
        .where((index) => !items[index].imagePaths.contains(photoPath))
        .toList();
    if (additions.isEmpty) {
      showToast(context, '所选菜品已使用这张照片');
      return;
    }

    final changed = [...items];
    for (final index in additions) {
      final dish = changed[index];
      changed[index] = VisitDish.fromJson(dish.toJson())
        ..imagePaths = [...dish.imagePaths, photoPath];
    }
    final message = '已为 ${additions.length} 道菜添加照片';
    final saved = await _changeFoods(
      nextItems: changed,
      nextPackages: packages,
      message: message,
    );
    if (saved && mounted && !_independentFoods) {
      showToast(context, message);
    }
  }

  Future<Set<int>?> _selectPhotoDishes() {
    final selected = <int>{};
    final dishes = items.indexed.where((entry) => entry.$2.isDish).toList();
    final colors = Theme.of(context).colorScheme;
    return showMenuBottomSheet<Set<int>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MenuSheetHeader('选择菜品'),
              const SizedBox(height: 2),
              Flexible(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: dishes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final (position, dish) = dishes[index];
                    final checked = selected.contains(position);
                    return Semantics(
                      checked: checked,
                      child: Material(
                        color: checked
                            ? colors.primary.withValues(alpha: .08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setSheetState(() {
                            if (checked) {
                              selected.remove(position);
                            } else {
                              selected.add(position);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              spacing: 12,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox.square(
                                    dimension: 36,
                                    child: dish.imagePaths.isEmpty
                                        ? ColoredBox(
                                            color: colors.surfaceContainer,
                                            child: Center(
                                              child: MenuIcon(
                                                Icons.ramen_dining_outlined,
                                                size: 20,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          )
                                        : LocalPhoto(
                                            path: dish.imagePaths.first,
                                          ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    dish.name.isEmpty
                                        ? '未命名菜品 ${index + 1}'
                                        : dish.name,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                SizedBox(
                                  width: 22,
                                  child: checked
                                      ? MenuIcon(
                                          Icons.check,
                                          size: 22,
                                          color: colors.primary,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '已选 ${selected.length} 道菜',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, selected),
                    child: const Text('选照片'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
