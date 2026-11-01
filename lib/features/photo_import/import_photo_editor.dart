import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/photo_location.dart';
import '../../ui/widgets.dart';
import '../media/media_actions.dart';
import '../restaurants/restaurant_address_editor.dart';
import 'import_models.dart';

class ImportPhotoEdit {
  ImportPhotoEdit(this.photo, this.addresses);
  final ImportPhoto photo;
  final List<RestaurantAddress> addresses;
}

Future<DateTime?> choosePhotoTime(
  BuildContext context,
  DateTime? current,
) async {
  final selected = await showDatePicker(
    context: context,
    helpText: '选择实际拍摄日期',
    initialDate: current ?? DateTime.now(),
    firstDate: DateTime(1900),
    lastDate: DateTime(2100, 12, 31),
  );
  if (selected == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    helpText: '选择实际拍摄时间',
    initialTime: current == null
        ? const TimeOfDay(hour: 12, minute: 0)
        : TimeOfDay.fromDateTime(current),
  );
  if (time == null) return null;
  return DateTime(
    selected.year,
    selected.month,
    selected.day,
    time.hour,
    time.minute,
  );
}

Future<RestaurantAddress?> choosePhotoBranch(
  BuildContext context,
  List<RestaurantAddress> addresses,
) => showModalBottomSheet<RestaurantAddress>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(20),
        child: Text('选择照片对应的分店', style: Theme.of(context).textTheme.titleLarge),
      ),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in addresses)
              ListTile(
                title: Text(a.fullAddress),
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ],
  ),
);

class ImportPhotoEditor extends StatefulWidget {
  const ImportPhotoEditor({
    super.key,
    required this.photo,
    required this.addresses,
  });
  final ImportPhoto photo;
  final List<RestaurantAddress> addresses;
  @override
  State<ImportPhotoEditor> createState() => _ImportPhotoEditorState();
}

class _ImportPhotoEditorState extends State<ImportPhotoEditor> {
  late final photo = widget.photo.copy();
  late final addresses = [...widget.addresses];
  late final name = TextEditingController(text: photo.name);
  late final price = TextEditingController(
    text: photo.price == 0 ? '' : money(photo.price),
  );
  late final quantity = TextEditingController(text: '${photo.quantity}');
  bool busy = false;
  bool leaving = false;
  bool get dirty =>
      photo.date != widget.photo.date ||
      photo.addressId != widget.photo.addressId ||
      photo.kind != widget.photo.kind ||
      name.text != widget.photo.name ||
      price.text !=
          (widget.photo.price == 0 ? '' : money(widget.photo.price)) ||
      quantity.text != '${widget.photo.quantity}' ||
      addresses.length != widget.addresses.length;
  @override
  void initState() {
    super.initState();
    for (final c in [name, price, quantity]) {
      c.addListener(changed);
    }
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    for (final c in [name, price, quantity]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> leave() async {
    if (busy) return;
    if (dirty &&
        !await confirmAction(
          context,
          title: '放弃照片设置？',
          message: '这张照片的修改还未完成。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context);
  }

  Future<void> addAddress({RestaurantAddress? suggestion}) async {
    final address = await editRestaurantAddress(context, address: suggestion);
    if (address == null || !mounted) return;
    final existing = addresses
        .where((a) => a.fullAddress == address.fullAddress)
        .firstOrNull;
    setState(() {
      if (existing == null) addresses.add(address);
      photo.addressId = existing?.id ?? address.id;
    });
  }

  Future<void> identify() async {
    setState(() => busy = true);
    RestaurantAddress? suggestion;
    final success = await performAction(context, () async {
      suggestion = await resolvePhotoAddress(photo.latitude!, photo.longitude!);
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!success) return;
    if (suggestion == null) {
      showToast(context, '未能识别地点，请手动填写分店地址');
      return;
    }
    await addAddress(suggestion: suggestion);
  }

  Future<void> branch() async {
    if (addresses.isEmpty) {
      await addAddress();
      return;
    }
    final selected = await choosePhotoBranch(context, addresses);
    if (selected != null && mounted) {
      setState(() => photo.addressId = selected.id);
    }
  }

  void done() {
    final amount = price.text.trim().isEmpty
        ? 0.0
        : double.tryParse(price.text.trim());
    final count = int.tryParse(quantity.text.trim());
    if (photo.kind == ImportPhotoKind.dish) {
      if (name.text.trim().isEmpty) {
        showToast(context, '请填写这张菜品照片的菜名');
        return;
      }
      if (amount == null || !amount.isFinite || amount < 0) {
        showToast(context, '请输入有效的菜品单价');
        return;
      }
      if (count == null || count < 1 || count > 100) {
        showToast(context, '数量应为1到100份');
        return;
      }
    }
    if (photo.kind == ImportPhotoKind.dish) {
      photo.name = name.text.trim();
      photo.price = amount!;
      photo.quantity = count!;
    }
    setState(() => leaving = true);
    Navigator.pop(context, ImportPhotoEdit(photo, addresses));
  }

  @override
  Widget build(BuildContext context) {
    final branch = addresses.where((a) => a.id == photo.addressId).firstOrNull;
    return PopScope(
      canPop: leaving || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('照片设置'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: busy ? null : leave,
            icon: const MenuIcon(Icons.arrow_back),
          ),
          actions: [
            TextButton(onPressed: busy ? null : done, child: const Text('完成')),
          ],
        ),
        body: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SizedBox(
                height: 220,
                child: InkWell(
                  onTap: () => showPhotoViewer(context, [photo.path], 0),
                  child: LocalPhoto(path: photo.path, fit: BoxFit.contain),
                ),
              ),
              const SectionTitle('拍摄时间'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  photo.date == null
                      ? '待填写实际拍摄时间'
                      : '${dayLabel(photo.date!)} ${TimeOfDay.fromDateTime(photo.date!).format(context)}',
                ),
                trailing: const MenuIcon(Icons.calendar_month_outlined),
                onTap: () async {
                  final date = await choosePhotoTime(context, photo.date);
                  if (date != null && mounted) {
                    setState(() => photo.date = date);
                  }
                },
              ),
              SectionTitle(
                '所属分店',
                trailing: TextButton(
                  onPressed: () => addAddress(),
                  child: const Text('新增分店'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(branch?.fullAddress ?? '待选择分店'),
                trailing: const MenuIcon(Icons.chevron_right),
                onTap: this.branch,
              ),
              if (photo.latitude != null && photo.longitude != null)
                OutlinedButton.icon(
                  onPressed: identify,
                  icon: const MenuIcon(Icons.place_outlined),
                  label: Text(busy ? '正在识别地点' : '识别照片地点'),
                ),
              const SectionTitle('照片用途'),
              SegmentedButton<ImportPhotoKind>(
                segments: const [
                  ButtonSegment(
                    value: ImportPhotoKind.environment,
                    label: Text('环境照片'),
                  ),
                  ButtonSegment(
                    value: ImportPhotoKind.dish,
                    label: Text('菜品照片'),
                  ),
                ],
                selected: {photo.kind},
                onSelectionChanged: (selected) =>
                    setState(() => photo.kind = selected.single),
              ),
              if (photo.kind == ImportPhotoKind.dish) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '菜品名称'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '本次单价',
                    prefixText: '¥ ',
                    hintText: '选填',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '本次点单数量',
                    suffixText: '份',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('同一道菜的多张照片可在下一步合并，份数按实际点单确认。'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
