import '../../ui/menu_popup.dart';
import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import '../restaurants/restaurant_address_editor.dart';
import 'import_models.dart';
import 'import_photo_editor.dart';
import 'photo_import_preview.dart';

class PhotoImportPage extends StatefulWidget {
  const PhotoImportPage({super.key, this.restaurantId});
  final String? restaurantId;
  @override
  State<PhotoImportPage> createState() => _PhotoImportPageState();
}

class _PhotoImportPageState extends State<PhotoImportPage> {
  final name = TextEditingController();
  final category = TextEditingController();
  final photos = <ImportPhoto>[];
  final selected = <int>{};
  List<RestaurantAddress> addresses = [];
  int initialAddressCount = 0;
  final initialAddressIds = <String>{};
  bool initialized = false;
  bool busy = false;
  bool leaving = false;
  bool get dirty =>
      photos.isNotEmpty ||
      name.text.isNotEmpty ||
      category.text.isNotEmpty ||
      addresses.length != initialAddressCount;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      if (widget.restaurantId != null) {
        final r = MenuScope.of(
          context,
        ).data.restaurants.firstWhere((r) => r.id == widget.restaurantId);
        addresses = [...r.addressEntries];
        initialAddressCount = addresses.length;
        initialAddressIds.addAll(addresses.map((a) => a.id));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    name.addListener(changed);
    category.addListener(changed);
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    name.dispose();
    category.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (busy) return;
    if (dirty &&
        !await confirmAction(
          context,
          title: '退出照片导入？',
          message: '照片设置和未导入的记录将不会保存。',
          confirmLabel: '退出导入',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context);
  }

  Future<void> pick() async {
    setState(() => busy = true);
    await performAction(context, () async {
      final files = await MenuScope.of(context).photos.pick();
      final added = <ImportPhoto>[];
      for (var offset = 0; offset < files.length; offset += 8) {
        added.addAll(
          await Future.wait(files.skip(offset).take(8).map(readImportPhoto)),
        );
      }
      if (mounted) setState(() => photos.addAll(added));
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> addAddress() async {
    final result = await editRestaurantAddress(context);
    if (result == null || !mounted) return;
    if (addresses.any((a) => a.fullAddress == result.fullAddress)) {
      showToast(context, '这个分店已经添加过了');
      return;
    }
    setState(() => addresses.add(result));
  }

  Future<void> editAddress(int index) async {
    final result = await editRestaurantAddress(
      context,
      address: addresses[index],
    );
    if (result == null || !mounted) return;
    if (addresses.any(
      (a) => a.id != result.id && a.fullAddress == result.fullAddress,
    )) {
      showToast(context, '这个分店已经添加过了');
      return;
    }
    setState(() => addresses[index] = result);
  }

  Future<void> removeAddress(int index) async {
    final address = addresses[index];
    final count = photos.where((p) => p.addressId == address.id).length;
    if (!await confirmAction(
      context,
      title: '移除本次新增分店？',
      message:
          '${address.fullAddress}${count > 0 ? '\n关联的 $count 张照片将需要重新指定分店。' : ''}',
      confirmLabel: '移除',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      addresses.removeAt(index);
      for (final photo in photos) {
        if (photo.addressId == address.id) photo.addressId = '';
      }
    });
  }

  Future<void> batchTime() async {
    final date = await choosePhotoTime(context, null);
    if (date != null && mounted) {
      setState(() {
        for (final index in selected) {
          photos[index].date = date;
        }
      });
      showToast(context, '已为 ${selected.length} 张照片设置拍摄时间');
    }
  }

  Future<void> batchAddress() async {
    if (addresses.isEmpty) {
      showToast(context, '请先添加照片对应的分店地址');
      return;
    }
    final address = await choosePhotoBranch(context, addresses);
    if (address != null && mounted) {
      setState(() {
        for (final index in selected) {
          photos[index].addressId = address.id;
        }
      });
      showToast(context, '已为 ${selected.length} 张照片指定分店');
    }
  }

  Future<void> editPhoto(int index) async {
    final result = await Navigator.push<ImportPhotoEdit>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportPhotoEditor(
          photo: photos[index],
          addresses: addresses,
          lockedAddressIds: initialAddressIds,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        photos[index] = result.photo;
        addresses = result.addresses;
      });
    }
  }

  Future<void> removeSelected() async {
    if (!await confirmAction(
      context,
      title: '移除所选照片？',
      message: '从这次导入中移除 ${selected.length} 张照片，原照片不会被删除。',
      confirmLabel: '移除',
    )) {
      return;
    }
    if (mounted) {
      setState(() {
        final indexes = selected.toList()..sort((a, b) => b.compareTo(a));
        for (final index in indexes) {
          photos.removeAt(index);
        }
        selected.clear();
      });
    }
  }

  Future<void> preview() async {
    if (widget.restaurantId == null && name.text.trim().isEmpty) {
      showToast(context, '请填写餐厅名称');
      return;
    }
    if (photos.isEmpty) {
      showToast(context, '请先选择照片');
      return;
    }
    final missingDate = photos.indexWhere((p) => p.date == null);
    if (missingDate >= 0) {
      showToast(context, '请补充第 ${missingDate + 1} 张照片的实际拍摄时间');
      return;
    }
    final missingAddress = photos.indexWhere((p) => p.addressId.isEmpty);
    if (missingAddress >= 0) {
      showToast(context, '请为第 ${missingAddress + 1} 张照片指定分店');
      return;
    }
    final groups = groupImportPhotos(photos, addresses);
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoImportPreview(
          restaurantId: widget.restaurantId,
          name: name.text.trim(),
          category: category.text.trim(),
          addresses: addresses,
          groups: groups,
        ),
      ),
    );
    if (imported == true && mounted) {
      setState(() => leaving = true);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.restaurantId == null
        ? null
        : MenuScope.of(
            context,
          ).data.restaurants.firstWhere((r) => r.id == widget.restaurantId);
    return PopScope(
      canPop: leaving || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(existing == null ? '从照片创建餐厅' : '从照片添加用餐记录'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: busy ? null : leave,
            icon: const MenuIcon(Icons.arrow_back),
          ),
          actions: [
            if (photos.isNotEmpty)
              IconButton(
                tooltip: '继续选择照片',
                onPressed: busy ? null : pick,
                icon: const MenuIcon(Icons.add_photo_alternate_outlined),
              ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            children: [
              if (existing == null) ...[
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '餐厅名称'),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    hintText: '如川菜、咖啡',
                  ),
                ),
              ] else
                Text(
                  existing.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              const SizedBox(height: 18),
              const Text(
                '先核对每张照片的实际拍摄时间和分店，再预览用餐记录。缺少拍摄信息的照片可手动补充，照片默认作为环境记录。',
                style: TextStyle(height: 1.6),
              ),
              SectionTitle(
                '分店地址 · ${addresses.length}',
                trailing: TextButton.icon(
                  onPressed: addAddress,
                  icon: const MenuIcon(Icons.add, size: 18),
                  label: const Text('添加分店'),
                ),
              ),
              if (addresses.isEmpty)
                const Text('添加地址后，逐张或批量指定照片对应的分店。')
              else
                for (var index = 0; index < addresses.length; index++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(addresses[index].fullAddress),
                    onTap: initialAddressIds.contains(addresses[index].id)
                        ? null
                        : () => editAddress(index),
                    trailing: initialAddressIds.contains(addresses[index].id)
                        ? null
                        : MenuPopupButton<String>(
                            icon: const MenuIcon(Icons.more_horiz),
                            tooltip: '本次新增分店操作',
                            onSelected: (value) {
                              if (value == 'edit') {
                                editAddress(index);
                              } else {
                                removeAddress(index);
                              }
                            },
                            itemBuilder: (_) => const [
                              MenuPopupItem(
                                icon: Icons.edit_outlined,
                                value: 'edit',
                                child: Text('修改新增分店'),
                              ),
                              MenuPopupItem(
                                icon: Icons.delete_outline,
                                destructive: true,
                                value: 'remove',
                                child: Text('移除新增分店'),
                              ),
                            ],
                          ),
                  ),
              SectionTitle(
                '照片 · ${photos.length}',
                trailing: photos.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => setState(() {
                          if (selected.length == photos.length) {
                            selected.clear();
                          } else {
                            selected.addAll(
                              List.generate(photos.length, (i) => i),
                            );
                          }
                        }),
                        child: Text(
                          selected.length == photos.length ? '取消全选' : '全选',
                        ),
                      ),
              ),
              if (photos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: FilledButton.icon(
                    onPressed: pick,
                    icon: const MenuIcon(Icons.photo_library_outlined),
                    label: Text(busy ? '正在读取照片' : '选择照片'),
                  ),
                ),
              if (photos.isNotEmpty) ...[
                if (selected.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: batchTime,
                        icon: const MenuIcon(
                          Icons.calendar_month_outlined,
                          size: 18,
                        ),
                        label: Text('为 ${selected.length} 张设置时间'),
                      ),
                      OutlinedButton.icon(
                        onPressed: batchAddress,
                        icon: const MenuIcon(Icons.place_outlined, size: 18),
                        label: const Text('指定分店'),
                      ),
                      TextButton(
                        onPressed: removeSelected,
                        child: const Text('移除所选'),
                      ),
                    ],
                  )
                else
                  Text(
                    '勾选照片后，可批量设置时间或指定同一分店。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 12),
                for (var i = 0; i < photos.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Checkbox(
                          value: selected.contains(i),
                          onChanged: (value) => setState(() {
                            if (value!) {
                              selected.add(i);
                            } else {
                              selected.remove(i);
                            }
                          }),
                        ),
                        SizedBox(
                          width: 64,
                          height: 72,
                          child: InkWell(
                            onTap: () => showPhotoViewer(
                              context,
                              photos.map((p) => p.path).toList(),
                              i,
                              heroTagForIndex: (index) =>
                                  (this, photos[index].path),
                            ),
                            child: Hero(
                              tag: (this, photos[i].path),
                              child: LocalPhoto(path: photos[i].path),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              photos[i].kind == ImportPhotoKind.dish
                                  ? photos[i].name
                                  : '环境照片 ${i + 1}',
                            ),
                            subtitle: Text(
                              '${photos[i].date == null ? '待填写实际拍摄时间' : '${dayLabel(photos[i].date!)} ${TimeOfDay.fromDateTime(photos[i].date!).format(context)}'}\n${addresses.where((a) => a.id == photos[i].addressId).firstOrNull?.fullAddress ?? '待指定分店'}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const MenuIcon(
                              Icons.edit_outlined,
                              size: 19,
                            ),
                            onTap: () => editPhoto(i),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(onPressed: preview, child: const Text('预览用餐记录')),
              ],
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
