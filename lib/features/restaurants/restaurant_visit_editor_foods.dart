part of 'restaurant_visit_editor.dart';

Map<String, dynamic> _visitFoods(Visit visit) => {
  'items': visit.items.map((item) => item.toJson()).toList(),
  'packages': visit.packages.map((package) => package.toJson()).toList(),
  'currency': visit.currency.code,
};

Map<String, dynamic> _visitMetadata(Visit visit) {
  final metadata = visit.toJson(includeFoods: false);
  if (visit.autoCost) metadata.remove('totalCost');
  return metadata;
}

extension _RestaurantVisitEditorFoods on _RestaurantVisitEditorState {
  Future<bool> _changeFoods({
    required List<VisitDish> nextItems,
    required List<VisitPackage> nextPackages,
    MenuCurrency? nextCurrency,
    String? message,
  }) async {
    dismissDishUndo?.call();
    final oldItems = items;
    final oldPackages = packages;
    final oldCurrency = currency;
    final oldTotal = total.text;
    updateForm(() {
      items = nextItems;
      packages = nextPackages;
      if (nextCurrency != null) currency = nextCurrency;
      recalculate();
      if (_independentFoods) foodSaving = true;
    });
    if (!_independentFoods) return true;
    final before = _savedVisit!;
    final edited = Visit.fromJson(before.toJson())
      ..items = nextItems
      ..packages = nextPackages;
    if (nextCurrency != null) edited.currency = nextCurrency;
    if (jsonEncode(_visitFoods(before)) == jsonEncode(_visitFoods(edited))) {
      updateForm(() => saving = false);
      return true;
    }
    final changes = RestaurantRecordDraft([before]);
    changes.records[0] = edited;
    final store = MenuScope.of(context);
    final success = await performAction(context, () async {
      final prepared = (await changes.prepare(store)).single;
      await store.update(
        MenuWriteScope.visit(widget.restaurant.id, before.id),
        (data) {
          final current = data.restaurants
              .firstWhere((r) => r.id == widget.restaurant.id)
              .records
              .where((visit) => visit.id == before.id)
              .firstOrNull;
          requireUnchangedRecord(
            _visitFoods(before),
            current == null ? null : _visitFoods(current),
          );
          current!.items = prepared.items;
          current.packages = prepared.packages;
          current.currency = prepared.currency;
          current.dishes = prepared.items.map((item) => item.name).toList();
          if (current.autoCost) current.totalCost = current.bill.total;
        },
      );
    }, success: message);
    if (!mounted) return success;
    updateForm(() {
      foodSaving = false;
      if (success) {
        final saved = store.data.restaurants
            .firstWhere((r) => r.id == widget.restaurant.id)
            .records
            .firstWhere((visit) => visit.id == before.id);
        items = saved.items
            .map((item) => VisitDish.fromJson(item.toJson()))
            .toList();
        packages = [...saved.packages];
        final baseline = _savedVisit;
        baseline.items = items;
        baseline.packages = packages;
        baseline.currency = saved.currency;
        baseline.dishes = saved.dishes;
        if (baseline.autoCost && saved.autoCost) {
          baseline.totalCost = saved.totalCost;
        }
        if (nextCurrency != null) currency = saved.currency;
        recalculate();
      } else {
        items = oldItems
            .map((item) => VisitDish.fromJson(item.toJson()))
            .toList();
        packages = oldPackages;
        currency = oldCurrency;
        total.text = oldTotal;
      }
    });
    return success;
  }

  Future<void> addItem({String? packageId}) async {
    var selectedCurrency = currency;
    final item = await editVisitDish(
      context,
      VisitDish(dishId: newId(), name: '', packageId: packageId),
      packages: packages,
      currency: currency,
      onCurrencyChanged: (value) => selectedCurrency = value,
      restaurantId: widget.draftOnly ? null : widget.restaurant.id,
      onSave: _independentFoods
          ? (item, selected) => _changeFoods(
              nextItems: [...items, item],
              nextPackages: packages,
              nextCurrency: selected,
              message: '菜品已保存',
            )
          : null,
    );
    if (item == null || !mounted || _independentFoods) return;
    await _changeFoods(
      nextItems: [...items, item],
      nextPackages: packages,
      nextCurrency: selectedCurrency,
      message: '菜品已保存',
    );
  }

  Future<void> editItem(int index) async {
    final original = items[index];
    var selectedCurrency = currency;
    final item = await editVisitDish(
      context,
      original,
      packages: packages,
      currency: currency,
      onCurrencyChanged: (value) => selectedCurrency = value,
      restaurantId: widget.draftOnly ? null : widget.restaurant.id,
      onSave: _independentFoods
          ? (item, selected) {
              final changed = [...items];
              changed[changed.indexWhere(
                    (dish) => dish.dishId == original.dishId,
                  )] =
                  item;
              return _changeFoods(
                nextItems: changed,
                nextPackages: packages,
                nextCurrency: selected,
                message: '菜品已保存',
              );
            }
          : null,
    );
    if (item == null || !mounted || _independentFoods) return;
    final changed = [...items];
    changed[changed.indexOf(original)] = item;
    await _changeFoods(
      nextItems: changed,
      nextPackages: packages,
      nextCurrency: selectedCurrency,
      message: '菜品已保存',
    );
  }

  Future<void> addPhotoItems({String? packageId}) async {
    updateForm(() => picking = true);
    await performAction(context, () async {
      final paths = await MenuScope.of(context).photos.pick();
      final photos = <ImportPhoto>[];
      for (var offset = 0; offset < paths.length; offset += 8) {
        photos.addAll(
          await Future.wait(paths.skip(offset).take(8).map(readImportPhoto)),
        );
      }
      if (!mounted || photos.isEmpty) return;
      if (items.isEmpty && widget.visit == null) {
        final dates = photos.map((p) => p.date).whereType<DateTime>().toList()
          ..sort();
        if (dates.isNotEmpty) updateForm(() => date = dates.first);
      }
      await _changeFoods(
        nextItems: [
          ...items,
          for (final photo in photos)
            VisitDish(
              dishId: newId(),
              name: '',
              packageId: packageId,
              imagePaths: [photo.path],
            ),
        ],
        nextPackages: packages,
      );
    });
    if (mounted) updateForm(() => picking = false);
  }

  Future<void> editPackage([VisitPackage? package]) async {
    var selectedCurrency = currency;
    final result = await showVisitPackageEditor(
      context,
      package: package,
      currency: currency,
      onCurrencyChanged: (value) => selectedCurrency = value,
      onSave: _independentFoods
          ? (result, selected) {
              final changed = [...packages];
              if (package == null) {
                changed.add(result);
              } else {
                changed[changed.indexWhere((p) => p.id == package.id)] = result;
              }
              return _changeFoods(
                nextItems: items,
                nextPackages: changed,
                nextCurrency: selected,
                message: '套餐已保存',
              );
            }
          : null,
    );
    if (!mounted || result == null || _independentFoods) return;
    final changed = [...packages];
    if (package == null) {
      changed.add(result);
    } else {
      changed[changed.indexWhere((p) => p.id == package.id)] = result;
    }
    await _changeFoods(
      nextItems: items,
      nextPackages: changed,
      nextCurrency: selectedCurrency,
      message: '套餐已保存',
    );
  }

  Future<void> moveGroupItem(String? packageId, int from, int to) async {
    final positions = [
      for (var i = 0; i < items.length; i++)
        if (items[i].packageId == packageId) i,
    ];
    final ordered = [for (final position in positions) items[position]];
    final dish = ordered.removeAt(from);
    ordered.insert(to, dish);
    final changed = [...items];
    for (var i = 0; i < positions.length; i++) {
      changed[positions[i]] = ordered[i];
    }
    await _changeFoods(nextItems: changed, nextPackages: packages);
  }

  Future<void> removePackage(VisitPackage package) async {
    final count = items.where((i) => i.packageId == package.id).length;
    final remaining = packages.where((p) => p.id != package.id).toList();
    final unbound = items.map((i) {
      final item = VisitDish.fromJson(i.toJson());
      if (item.packageId == package.id) item.packageId = null;
      return item;
    }).toList();
    final after = VisitBill(visitSubtotal(unbound, remaining), coupons);
    if (!await confirmAction(
      context,
      title: '解除“${package.name}”？',
      message:
          '${count > 0 ? '保留 $count 道菜并改为单点，恢复各自单价。' : '套餐总价将不再计入消费。'}'
          '${autoCost ? '自动实付将从 ${currency.symbol}${money(bill.total)} 改为 ${currency.symbol}${money(after.total)}。' : '手填实付金额保持不变。'}',
      confirmLabel: '解除套餐',
    )) {
      return;
    }
    if (!mounted) return;
    await _changeFoods(nextItems: unbound, nextPackages: remaining);
  }

  Future<void> removeItem(VisitDish dish) async {
    final index = items.indexOf(dish);
    final changed = [...items]..removeAt(index);
    if (!await _changeFoods(nextItems: changed, nextPackages: packages) ||
        !mounted) {
      return;
    }
    dismissDishUndo = showToast(
      context,
      dish.name.isEmpty ? '已移除菜品' : '已移除“${dish.name}”',
      onAction: () {
        final restored = [...items]..insert(index.clamp(0, items.length), dish);
        _changeFoods(nextItems: restored, nextPackages: packages);
      },
    );
  }
}
