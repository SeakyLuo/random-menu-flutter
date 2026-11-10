import '../../ui/menu_popup.dart';
import '../../ui/menu_currency_picker.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../core/geo_point.dart';
import '../../ui/widgets.dart';
import '../restaurants/restaurant_images.dart';
import '../restaurants/visit_dish_editor.dart';
import 'import_models.dart';
import 'split_visit_page.dart';

class PhotoImportPreview extends StatefulWidget {
  const PhotoImportPreview({
    super.key,
    this.restaurantId,
    required this.name,
    required this.category,
    required this.addresses,
    required this.groups,
  });
  final String? restaurantId;
  final String name;
  final String category;
  final List<RestaurantAddress> addresses;
  final List<ImportVisit> groups;
  @override
  State<PhotoImportPreview> createState() => _PhotoImportPreviewState();
}

class _PhotoImportPreviewState extends State<PhotoImportPreview> {
  late final groups = [...widget.groups];
  bool saving = false;
  bool leaving = false;
  bool changed = false;
  Future<void> leave() async {
    if (saving) return;
    if (changed &&
        !await confirmAction(
          context,
          title: '返回照片设置？',
          message: '返回后将按照片设置重新分组，需要重新核对本页的合并和菜品调整。',
          confirmLabel: '返回设置',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context, false);
  }

  Future<void> editItem(ImportVisit group, int index) async {
    final result = await editVisitDish(
      context,
      group.items[index],
      currency: group.currency,
      onCurrencyChanged: (value) => group.currency = value,
    );
    if (result != null && mounted) {
      setState(() {
        group.items[index] = result;
        group.separateDishesConfirmed = false;
        changed = true;
      });
    }
  }

  Future<void> mergeDishes(ImportVisit group, String name) async {
    final same = group.items.where((i) => i.name == name).toList();
    final prices = same.map((i) => i.price).toSet();
    if (!await confirmAction(
      context,
      title: '合并同一道菜的照片？',
      message: '将“$name”的 ${same.length} 条明细合并为一条。下一步请确认实际单价和点单份数，份数不会按照片数相加。',
      confirmLabel: '核对合并明细',
      destructive: false,
    )) {
      return;
    }
    if (!mounted) return;
    final result = await editVisitDish(
      context,
      VisitDish(
        dishId: newId(),
        name: name,
        price: same.first.price,
        quantity: 1,
        note: same
            .map((i) => i.note)
            .where((n) => n.isNotEmpty)
            .toSet()
            .join('\n'),
        imagePaths: same.expand((i) => i.imagePaths).toList(),
      ),
      requirePrice: prices.length > 1,
      currency: group.currency,
      onCurrencyChanged: (value) => group.currency = value,
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = group.items.indexWhere((i) => i.name == name);
      group.items.removeWhere((i) => i.name == name);
      group.items.insert(index, result);
      group.separateDishesConfirmed = false;
      changed = true;
    });
  }

  Future<void> splitDish(ImportVisit group, int index) async {
    final item = group.items[index];
    if (!await confirmAction(
      context,
      title: '按照片拆分菜品？',
      message: '每张照片将成为一条独立明细，初始数量为1份。拆分后请逐条核对实际单价和份数，避免重复计费。',
      confirmLabel: '拆分并核对',
      destructive: false,
    )) {
      return;
    }
    if (mounted) {
      setState(() {
        group.items.removeAt(index);
        group.items.insertAll(index, [
          for (final path in item.imagePaths)
            VisitDish(
              dishId: newId(),
              name: item.name,
              isDish: item.isDish,
              price: item.price,
              quantity: 1,
              note: item.note,
              imagePaths: [path],
            ),
        ]);
        group.separateDishesConfirmed = false;
        changed = true;
      });
    }
  }

  Future<void> mergeRecords(ImportVisit group) async {
    final candidates = groups
        .where(
          (g) =>
              g != group &&
              g.address.id == group.address.id &&
              g.currency == group.currency,
        )
        .toList();
    final target = await showDialog<ImportVisit>(
      context: context,
      builder: (context) => MenuDialog(
        title: '合并到哪次用餐？',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in candidates)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const MenuIcon(
                  Icons.calendar_today_outlined,
                  size: 20,
                ),
                title: Text(
                  '${dayLabel(g.date)} ${TimeOfDay.fromDateTime(g.date).format(context)}',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                subtitle: Text('${g.photos.length} 张照片'),
                onTap: () => Navigator.pop(context, g),
              ),
          ],
        ),
        actions: MenuDialogButton(
          label: '取消',
          role: MenuDialogRole.secondary,
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
    if (target == null || !mounted) return;
    final crossesDay =
        target.date.year != group.date.year ||
        target.date.month != group.date.month ||
        target.date.day != group.date.day;
    if (!await confirmAction(
      context,
      title: '确认是同一次用餐？',
      message: '${crossesDay ? '这两组照片来自不同日期。' : ''}合并后使用较早的拍摄时间，保留全部环境照片和菜品明细。',
      confirmLabel: '合并为一次用餐',
      destructive: false,
    )) {
      return;
    }
    if (mounted) {
      setState(() {
        target.date = target.date.isBefore(group.date)
            ? target.date
            : group.date;
        target.photos.addAll(group.photos);
        target.items.addAll(group.items);
        target.environments.addAll(group.environments);
        target.separateDishesConfirmed = false;
        groups.remove(group);
        groups.sort((a, b) => a.date.compareTo(b.date));
        changed = true;
      });
    }
  }

  Future<void> splitRecords(ImportVisit group) async {
    final selected = await Navigator.push<List<ImportPhoto>>(
      context,
      MaterialPageRoute(builder: (_) => SplitVisitPage(photos: group.photos)),
    );
    if (selected == null || !mounted) return;
    final chosen = selected.toSet();
    final remaining = group.photos
        .where((photo) => !chosen.contains(photo))
        .toList();
    setState(() {
      groups.remove(group);
      groups.add(
        importVisitFromPhotos(selected, group.address)
          ..currency = group.currency,
      );
      groups.add(
        importVisitFromPhotos(remaining, group.address)
          ..currency = group.currency,
      );
      groups.sort((a, b) => a.date.compareTo(b.date));
      changed = true;
    });
  }

  Future<void> save() async {
    if (groups.any((g) => g.duplicateDishes && !g.separateDishesConfirmed)) {
      showToast(context, '请合并同名菜品照片，或确认它们是独立点单');
      return;
    }
    final store = MenuScope.of(context);
    setState(() => saving = true);
    final success = await performAction(context, () async {
      final paths = {
        for (final group in groups) ...[
          ...group.environments,
          ...group.items.expand((i) => i.imagePaths),
        ],
      };
      final savedPaths = <String, String>{};
      for (final path in paths) {
        savedPaths[path] = path.startsWith('${store.directory.path}/images/')
            ? path
            : await store.keepImage(path);
      }
      final savedRestaurantId = widget.restaurantId ?? newId();
      await store.update(MenuWriteScope.restaurant(savedRestaurantId), (draft) {
        final restaurant = widget.restaurantId == null
            ? Restaurant(
                id: savedRestaurantId,
                name: widget.name,
                category: widget.category,
                addressEntries: [...widget.addresses],
                addresses: widget.addresses.map((a) => a.fullAddress).toList(),
                records: [],
              )
            : draft.restaurants.firstWhere((r) => r.id == widget.restaurantId);
        if (widget.restaurantId != null) {
          final existingIds = restaurant.addressEntries
              .map((a) => a.id)
              .toSet();
          restaurant.addressEntries.addAll(
            widget.addresses.where((a) => !existingIds.contains(a.id)),
          );
          restaurant.addresses = restaurant.addressEntries
              .map((a) => a.fullAddress)
              .toList();
        }
        final branches = {
          for (final address in restaurant.addressEntries) address.id: address,
        };
        for (final group in groups) {
          final branch = branches[group.address.id]!;
          if (branch.location == null) {
            final located = group.photos
                .where(
                  (photo) => photo.latitude != null && photo.longitude != null,
                )
                .firstOrNull;
            if (located != null) {
              branch.location = GeoPoint(
                latitude: located.latitude!,
                longitude: located.longitude!,
              );
            }
          }
          final items = <VisitDish>[];
          for (final item in group.items) {
            final photos = item.imagePaths
                .map((path) => savedPaths[path]!)
                .toList();
            items.add(
              VisitDish(
                dishId: newId(),
                name: item.name,
                isDish: item.isDish,
                price: item.price,
                quantity: item.quantity,
                note: item.note,
                imagePaths: photos,
              ),
            );
          }
          restaurant.records.add(
            Visit(
              id: newId(),
              date: group.date,
              addressId: group.address.id,
              address: group.address.fullAddress,
              autoCost: true,
              totalCost: group.total,
              currency: group.currency,
              items: items,
              dishes: items.map((i) => i.name).toList(),
              imagePaths: group.environments
                  .map((path) => savedPaths[path]!)
                  .toList(),
            ),
          );
        }
        if (widget.restaurantId == null) draft.restaurants.add(restaurant);
      });
    });
    if (!mounted) return;
    if (success) {
      showToast(
        context,
        '${widget.restaurantId == null ? '已创建餐厅并导入' : '已导入'} ${groups.length} 条消费记录',
      );
      setState(() => leaving = true);
      Navigator.pop(context, true);
    } else {
      setState(() => saving = false);
    }
  }

  String get restaurantName => widget.restaurantId == null
      ? widget.name
      : MenuScope.of(
          context,
        ).data.restaurants.firstWhere((r) => r.id == widget.restaurantId).name;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || (!changed && !saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: MenuScrollTitle(child: const Text('核对导入记录')),
        leading: IconButton(
          tooltip: '返回照片设置',
          onPressed: saving ? null : leave,
          icon: const MenuIcon(Icons.arrow_back),
        ),
      ),
      body: AbsorbPointer(
        absorbing: saving,
        child: ListView(
          primary: true,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          children: [
            Text(
              restaurantName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              '${groups.length} 条消费记录',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              '按同一分店、同一自然日、距该组首张照片不超过3小时分组。跨午夜或相隔更久的同一次用餐，可手动合并；同一组中的不同用餐可按照片拆分。',
              style: TextStyle(height: 1.6),
            ),
            const SizedBox(height: 12),
            const Text('导入后可在消费记录中补充饭搭子和用餐感受。'),
            const SizedBox(height: 20),
            for (final group in groups)
              Card(
                margin: const EdgeInsets.only(bottom: 18),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${dayLabel(group.date)} ${TimeOfDay.fromDateTime(group.date).format(context)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (group.photos.length > 1 ||
                              groups.any(
                                (g) =>
                                    g != group &&
                                    g.address.id == group.address.id &&
                                    g.currency == group.currency,
                              ))
                            MenuPopupButton<String>(
                              icon: const MenuIcon(Icons.more_horiz),
                              tooltip: '用餐分组操作',
                              onSelected: (value) {
                                if (value == 'merge') {
                                  mergeRecords(group);
                                } else {
                                  splitRecords(group);
                                }
                              },
                              itemBuilder: (_) => [
                                if (groups.any(
                                  (g) =>
                                      g != group &&
                                      g.address.id == group.address.id &&
                                      g.currency == group.currency,
                                ))
                                  const MenuPopupItem(
                                    icon: Icons.call_merge,
                                    value: 'merge',
                                    child: Text('合并到其他消费记录'),
                                  ),
                                if (group.photos.length > 1)
                                  const MenuPopupItem(
                                    icon: Icons.call_split,
                                    value: 'split',
                                    child: Text('拆分消费记录'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(group.address.fullAddress),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          MenuCurrencyPrefix(
                            currency: group.currency,
                            onChanged: (value) => setState(() {
                              group.currency = value;
                              changed = true;
                            }),
                          ),
                          Expanded(
                            child: Text(
                              '菜品合计 ${group.currency.symbol}${money(group.total)} · ${group.items.length} 条菜品明细',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (var i = 0; i < group.items.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            group.items[i].name.isEmpty
                                ? '未命名菜品'
                                : group.items[i].name,
                          ),
                          subtitle: Text(
                            '${group.currency.symbol}${money(group.items[i].price)} × ${group.items[i].quantity} 份 = ${group.currency.symbol}${money(group.items[i].cost)} · ${group.items[i].imagePaths.length} 张照片',
                          ),
                          onTap: () => editItem(group, i),
                          trailing: MenuPopupButton<String>(
                            icon: const MenuIcon(Icons.more_horiz),
                            tooltip: '菜品明细操作',
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  editItem(group, i);
                                case 'merge':
                                  mergeDishes(group, group.items[i].name);
                                case 'split':
                                  splitDish(group, i);
                              }
                            },
                            itemBuilder: (_) => [
                              const MenuPopupItem(
                                icon: Icons.edit_outlined,
                                value: 'edit',
                                child: Text('核对单价与数量'),
                              ),
                              if (group.items[i].name.isNotEmpty &&
                                  group.items
                                          .where(
                                            (item) =>
                                                item.name ==
                                                group.items[i].name,
                                          )
                                          .length >
                                      1)
                                const MenuPopupItem(
                                  icon: Icons.call_merge,
                                  value: 'merge',
                                  child: Text('合并同名菜品照片'),
                                ),
                              if (group.items[i].imagePaths.length > 1)
                                const MenuPopupItem(
                                  icon: Icons.call_split,
                                  value: 'split',
                                  child: Text('按照片拆分明细'),
                                ),
                            ],
                          ),
                        ),
                      if (group.duplicateDishes)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: group.separateDishesConfirmed,
                          title: const Text('这些同名明细是独立点单'),
                          subtitle: const Text('同一道菜的多张照片请先合并，避免重复计算份数和金额。'),
                          onChanged: (value) => setState(() {
                            group.separateDishesConfirmed = value!;
                            changed = true;
                          }),
                        ),
                      if (group.environments.isNotEmpty) ...[
                        SectionTitle('环境照片 · ${group.environments.length}'),
                        RestaurantImages(paths: group.environments),
                      ],
                    ],
                  ),
                ),
              ),
            FilledButton(
              onPressed: saving ? null : save,
              child: Text(
                saving
                    ? '正在导入…'
                    : widget.restaurantId == null
                    ? '创建餐厅并导入 ${groups.length} 次用餐'
                    : '导入 ${groups.length} 次用餐',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
