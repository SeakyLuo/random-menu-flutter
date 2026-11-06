import '../../ui/menu_icon.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../../ui/library_widgets.dart';
import 'restaurant_address_editor.dart';

Future<bool> editRestaurant(
  BuildContext context, {
  Restaurant? restaurant,
}) async =>
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => _RestaurantEditor(restaurant: restaurant),
      ),
    ) ==
    true;

class _RestaurantEditor extends StatefulWidget {
  const _RestaurantEditor({this.restaurant});
  final Restaurant? restaurant;
  @override
  State<_RestaurantEditor> createState() => _RestaurantEditorState();
}

class _RestaurantEditorState extends State<_RestaurantEditor> {
  late final name = TextEditingController(text: widget.restaurant?.name ?? '');
  late final category = TextEditingController(
    text: widget.restaurant?.category ?? '',
  );
  late final note = TextEditingController(text: widget.restaurant?.note ?? '');
  late final link = TextEditingController(text: widget.restaurant?.link ?? '');
  late List<RestaurantAddress> addresses = [
    ...?widget.restaurant?.addressEntries,
  ];
  late bool favorite = widget.restaurant?.favorite ?? false;
  bool saving = false;
  bool leaving = false;
  bool get dirty =>
      name.text != (widget.restaurant?.name ?? '') ||
      category.text != (widget.restaurant?.category ?? '') ||
      note.text != (widget.restaurant?.note ?? '') ||
      link.text != (widget.restaurant?.link ?? '') ||
      favorite != (widget.restaurant?.favorite ?? false) ||
      jsonEncode(addresses.map((a) => a.toJson()).toList()) !=
          jsonEncode(
            widget.restaurant?.addressEntries.map((a) => a.toJson()).toList() ??
                [],
          );
  @override
  void initState() {
    super.initState();
    for (final controller in [name, category, note, link]) {
      controller.addListener(changed);
    }
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    for (final controller in [name, category, note, link]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> leave() async {
    if (saving) return;
    if (dirty &&
        !await confirmAction(
          context,
          title: '放弃此次编辑？',
          message: '还未保存的修改将丢失。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context, false);
  }

  Future<void> addressForm([int? index]) async {
    final result = await editRestaurantAddress(
      context,
      address: index == null ? null : addresses[index],
    );
    if (result == null || !mounted) return;
    if (addresses.any(
      (a) => a.fullAddress == result.fullAddress && a.id != result.id,
    )) {
      showToast(context, '这个地址已经添加过了');
      return;
    }
    setState(() {
      if (index == null) {
        addresses.add(result);
      } else {
        addresses[index] = result;
      }
    });
  }

  Future<void> removeAddress(int index) async {
    final address = addresses[index];
    final records = widget.restaurant?.records ?? <Visit>[];
    if (records.any((r) => r.addressId == address.id)) {
      showToast(context, '已有用餐记录使用这个地址，请保留该分店');
      return;
    }
    if (!await confirmAction(
      context,
      title: '移除地址？',
      message: address.fullAddress,
      confirmLabel: '移除',
    )) {
      return;
    }
    if (mounted) setState(() => addresses.removeAt(index));
  }

  void moveAddress(int from, int to) => setState(() {
    final address = addresses.removeAt(from);
    addresses.insert(to, address);
  });
  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      showToast(context, '请填写餐厅名称');
      return;
    }
    setState(() => saving = true);
    final store = MenuScope.of(context);
    final success = await performAction(
      context,
      () => store.update((draft) {
        final restaurant = widget.restaurant == null
            ? Restaurant(id: newId(), name: name.text.trim())
            : draft.restaurants.firstWhere(
                (r) => r.id == widget.restaurant!.id,
              );
        restaurant.name = name.text.trim();
        restaurant.category = category.text.trim();
        restaurant.note = note.text.trim();
        restaurant.link = link.text.trim();
        restaurant.favorite = favorite;
        restaurant.addressEntries = addresses;
        restaurant.addresses = addresses.map((a) => a.fullAddress).toList();
        if (widget.restaurant == null) draft.restaurants.add(restaurant);
      }),
    );
    if (!mounted) return;
    if (success) {
      showToast(context, '餐厅已保存');
      setState(() => leaving = true);
      Navigator.pop(context, true);
    } else {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        MenuScope.of(context).data.restaurants
            .map((r) => r.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return PopScope(
      canPop: leaving || (!dirty && !saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.restaurant == null ? '添加餐厅' : '编辑餐厅'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: saving ? null : leave,
            icon: const MenuIcon(Icons.arrow_back),
          ),
        ),
        bottomNavigationBar: FixedPageActions(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? '保存中…' : '保存餐厅'),
              ),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: [
              TextField(
                controller: name,
                autofocus: widget.restaurant == null,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '餐厅名称',
                  hintText: '记下一家值得再去的店',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: category,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '菜系',
                  hintText: '如：川菜、咖啡、日料',
                ),
              ),
              if (categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final c in categories)
                        ActionChip(
                          label: Text(c),
                          onPressed: () => category.text = c,
                        ),
                    ],
                  ),
                ),
              SectionTitle(
                '分店地址',
                trailing: TextButton.icon(
                  onPressed: () => addressForm(),
                  icon: const MenuIcon(Icons.add, size: 18),
                  label: const Text('添加地址'),
                ),
              ),
              if (addresses.isEmpty) const Text('可以先保存餐厅，记录用餐时再补充地址。'),
              for (var i = 0; i < addresses.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(addresses[i].fullAddress),
                  onTap: () => addressForm(i),
                  trailing: PopupMenuButton<String>(
                    icon: const MenuIcon(Icons.more_horiz),
                    tooltip: '地址操作',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          addressForm(i);
                        case 'up':
                          moveAddress(i, i - 1);
                        case 'down':
                          moveAddress(i, i + 1);
                        case 'delete':
                          removeAddress(i);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑地址')),
                      if (i > 0)
                        const PopupMenuItem(value: 'up', child: Text('上移')),
                      if (i < addresses.length - 1)
                        const PopupMenuItem(value: 'down', child: Text('下移')),
                      const PopupMenuItem(value: 'delete', child: Text('移除地址')),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: note,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '口味、推荐理由或需要注意的事',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: link,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '相关链接',
                  hintText: '店铺或地图链接',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('收藏餐厅'),
                value: favorite,
                onChanged: (v) => setState(() => favorite = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
