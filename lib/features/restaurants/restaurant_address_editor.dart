import '../../ui/menu_icon.dart';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';

Future<RestaurantAddress?> editRestaurantAddress(
  BuildContext context, {
  RestaurantAddress? address,
}) => Navigator.push<RestaurantAddress>(
  context,
  MaterialPageRoute(builder: (_) => _AddressEditor(address: address)),
);

class _AddressEditor extends StatefulWidget {
  const _AddressEditor({this.address});
  final RestaurantAddress? address;
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  late final province = TextEditingController(
    text: widget.address?.province ?? '',
  );
  late final city = TextEditingController(text: widget.address?.city ?? '');
  late final county = TextEditingController(text: widget.address?.county ?? '');
  late final detail = TextEditingController(text: widget.address?.detail ?? '');
  bool leaving = false;
  bool get dirty =>
      province.text != (widget.address?.province ?? '') ||
      city.text != (widget.address?.city ?? '') ||
      county.text != (widget.address?.county ?? '') ||
      detail.text != (widget.address?.detail ?? '');
  @override
  void initState() {
    super.initState();
    for (final controller in [province, city, county, detail]) {
      controller.addListener(changed);
    }
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    for (final controller in [province, city, county, detail]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> leave() async {
    if (dirty &&
        !await confirmAction(
          context,
          title: '放弃地址修改？',
          message: '还未保存的地址修改将丢失。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context);
  }

  void save() {
    if (detail.text.trim().isEmpty) {
      showToast(context, '请填写详细地址');
      return;
    }
    setState(() => leaving = true);
    Navigator.pop(
      context,
      RestaurantAddress(
        id: widget.address?.id ?? newId(),
        province: province.text.trim(),
        city: city.text.trim(),
        county: county.text.trim(),
        detail: detail.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving || !dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.address == null ? '添加地址' : '编辑地址'),
        leading: IconButton(
          tooltip: '返回',
          onPressed: leave,
          icon: const MenuIcon(Icons.arrow_back),
        ),
        actions: [TextButton(onPressed: save, child: const Text('完成'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: province,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '省 / 自治区 / 直辖市',
              hintText: '选填，用于地区筛选',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: city,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '城市', hintText: '选填'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: county,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '区 / 县',
              hintText: '选填',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: detail,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '详细地址',
              hintText: '街道、门牌号或商场楼层',
            ),
          ),
        ],
      ),
    ),
  );
}
