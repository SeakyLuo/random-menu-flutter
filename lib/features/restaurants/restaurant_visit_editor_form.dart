part of 'restaurant_visit_editor.dart';

extension _RestaurantVisitEditorForm on _RestaurantVisitEditorState {
  Widget _selectionField(
    BuildContext context, {
    required String text,
    required VoidCallback onTap,
    bool isEmpty = false,
  }) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: isEmpty
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const MenuIcon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    ),
  );

  Widget _buildEditor(BuildContext context) {
    final allPeople =
        MenuScope.of(context).data.restaurants
            .expand((r) => r.records)
            .expand((r) => r.companions)
            .toSet()
            .toList()
          ..sort();
    return PopScope(
      canPop: leaving || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(widget.visit == null ? '添加消费记录' : '编辑消费记录'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: busy ? null : leave,
            icon: const MenuIcon(Icons.arrow_back),
          ),
        ),
        bottomNavigationBar: FixedPageActions(
          maxWidth: 560,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : save,
                child: Text(
                  saving
                      ? '保存中…'
                      : widget.draftOnly
                      ? '完成'
                      : '保存记录',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: busy,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverList.list(
                          children: [
                            const MenuFieldLabel(
                              '用餐时间',
                              icon: Icons.calendar_month_outlined,
                              minHeight: 44,
                              bottomSpacing: 4,
                            ),
                            _selectionField(
                              context,
                              text:
                                  '${dayLabel(date)} ${TimeOfDay.fromDateTime(date).format(context)}',
                              onTap: selectDate,
                            ),
                            const SizedBox(height: 16),
                            MenuFieldLabel(
                              '用餐分店',
                              icon: Icons.place_outlined,
                              minHeight: 44,
                              bottomSpacing: 4,
                              trailing: IconButton(
                                tooltip: '添加地址',
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: addAddress,
                                icon: const MenuIcon(Icons.add, size: 20),
                              ),
                            ),
                            _selectionField(
                              context,
                              text: address.isEmpty ? '选择本次用餐的分店' : address,
                              isEmpty: address.isEmpty,
                              onTap: chooseAddress,
                            ),
                            const SizedBox(height: 16),
                            RestaurantCompanionField(
                              controller: companions,
                              choices: allPeople,
                            ),
                            const SizedBox(height: 16),
                            MenuFieldLabel(
                              '总金额',
                              minHeight: 44,
                              bottomSpacing: 4,
                              trailing: MergeSemantics(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => changeAutoCost(!autoCost),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 44,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: autoCost,
                                          onChanged: (value) =>
                                              changeAutoCost(value!),
                                          activeColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        const Text(
                                          '自动计算',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            TextField(
                              controller: total,
                              style: const TextStyle(fontSize: 15),
                              readOnly: autoCost,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                hintText: '填写实际支付金额',
                                prefixText: '¥ ',
                              ),
                            ),
                            const SizedBox(height: 16),
                            VisitCouponFields(
                              coupons: coupons,
                              subtotal: subtotal,
                              autoCost: autoCost,
                              onChanged: (value) => updateForm(() {
                                coupons = value;
                                recalculate();
                              }),
                            ),
                            const SizedBox(height: 16),
                            const MenuFieldLabel(
                              '评价',
                              minHeight: 44,
                              bottomSpacing: 4,
                            ),
                            TextField(
                              controller: note,
                              style: const TextStyle(fontSize: 15, height: 1.6),
                              minLines: 3,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                hintText: '记下这次用餐的小细节',
                              ),
                            ),
                            const SizedBox(height: 24),
                            RestaurantImages(
                              paths: images,
                              editorStyle: true,
                              label: '环境照片',
                              onBusyChanged: (value) =>
                                  updateForm(() => picking = value),
                              onChanged: (v) {
                                if (mounted) updateForm(() => images = v);
                              },
                            ),
                            const SizedBox(height: 16),
                            VisitPackageFields(
                              packages: packages,
                              items: items,
                              onChanged: (value) => updateForm(() {
                                packages = value;
                                recalculate();
                              }),
                              onRemove: removePackage,
                            ),
                            const SizedBox(height: 16),
                            MenuFieldLabel(
                              '本次菜品 · ${items.length}',
                              minHeight: 44,
                              bottomSpacing: 4,
                              trailing: Tooltip(
                                message: widget.draftOnly
                                    ? '添加菜品，长按从照片快速添加'
                                    : '添加菜品',
                                triggerMode: widget.draftOnly
                                    ? TooltipTriggerMode.manual
                                    : TooltipTriggerMode.longPress,
                                child: GestureDetector(
                                  onLongPress: widget.draftOnly
                                      ? addPhotoItems
                                      : null,
                                  child: IconButton(
                                    onPressed: addItem,
                                    tooltip: '添加菜品',
                                    constraints: const BoxConstraints.tightFor(
                                      width: 44,
                                      height: 44,
                                    ),
                                    style: IconButton.styleFrom(
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const MenuIcon(Icons.add, size: 20),
                                  ),
                                ),
                              ),
                            ),
                            if (items.isEmpty)
                              Text(
                                '还没有添加菜品',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        SliverReorderableList(
                          itemCount: items.length,
                          onReorderItem: moveItem,
                          proxyDecorator: (child, index, animation) => child,
                          itemBuilder: (context, index) {
                            final dish = items[index];
                            return VisitDishEditorRow(
                              key: ObjectKey(dish),
                              dish: dish,
                              package: dish.packageId == null
                                  ? null
                                  : packages.firstWhere(
                                      (p) => p.id == dish.packageId,
                                    ),
                              index: index,
                              onEdit: () => editItem(index),
                              confirmRemove: () => confirmAction(
                                context,
                                title: '移除本次菜品？',
                                message: '从本次点单中移除“${dish.name}”，餐厅菜单会保留。',
                                confirmLabel: '移除',
                              ),
                              onRemove: () => removeItem(dish),
                            );
                          },
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
    );
  }
}
