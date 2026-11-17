import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/widgets.dart';
import 'restaurant_quick_create.dart';
import 'restaurant_record_draft.dart';
import 'restaurant_record_section.dart';
import 'restaurant_visit_editor.dart';

final _activePhotoRecords = <String>{};

Future<void> addRestaurantRecordsFromPhotos(
  BuildContext context,
  Restaurant restaurant,
) async {
  if (!_activePhotoRecords.add(restaurant.id)) return;
  final store = MenuScope.of(context);
  final selections = <String>[];
  try {
    await performAction(context, () async {
      try {
        final paths = await store.photos.pick(readLocation: true);
        selections.addAll(paths);
        if (paths.isEmpty) return;
        final draft = await buildRestaurantFromPhotos(paths);
        if (!context.mounted) return;
        if (draft.missingDates) {
          showToast(context, '部分照片没有拍摄时间，请核对消费日期');
        }
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _PhotoRecordsPage(
              restaurantId: restaurant.id,
              initial: draft,
              selections: selections,
            ),
          ),
        );
      } finally {
        await Future.wait(selections.map(store.photos.releaseSelection));
      }
    });
  } finally {
    _activePhotoRecords.remove(restaurant.id);
  }
}

class _PhotoRecordsPage extends StatefulWidget {
  const _PhotoRecordsPage({
    required this.restaurantId,
    required this.initial,
    required this.selections,
  });
  final String restaurantId;
  final RestaurantQuickDraft initial;
  final List<String> selections;
  @override
  State<_PhotoRecordsPage> createState() => _PhotoRecordsPageState();
}

class _PhotoRecordsPageState extends State<_PhotoRecordsPage> {
  final draft = RestaurantRecordDraft([]);
  final addresses = <RestaurantAddress>[];
  bool busy = false;
  bool leaving = false;
  bool initialized = false;
  Restaurant get restaurant => MenuScope.of(
    context,
  ).data.restaurants.firstWhere((entry) => entry.id == widget.restaurantId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    addresses.addAll(restaurant.addressEntries);
    append(widget.initial);
  }

  void append(RestaurantQuickDraft added) {
    for (final address in added.addresses) {
      final existing = addresses
          .where((a) => a.fullAddress == address.fullAddress)
          .firstOrNull;
      final target = existing ?? address;
      if (existing == null) addresses.add(address);
      for (final visit in added.records) {
        if (visit.addressId == address.id) {
          visit.addressId = target.id;
          visit.address = target.fullAddress;
        }
      }
    }
    for (final visit in added.records) {
      if (visit.addressId.isEmpty && addresses.length == 1) {
        visit.addressId = addresses.single.id;
        visit.address = addresses.single.fullAddress;
      }
    }
    draft.records.addAll(added.records);
  }

  Future<void> pick() async {
    setState(() => busy = true);
    await performAction(context, () async {
      final paths = await MenuScope.of(context).photos.pick(readLocation: true);
      widget.selections.addAll(paths);
      if (paths.isEmpty) return;
      final added = await buildRestaurantFromPhotos(paths);
      if (!mounted) return;
      setState(() => append(added));
      if (added.missingDates) showToast(context, '部分照片没有拍摄时间，请核对消费日期');
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> edit(Visit? visit) async {
    final source = Restaurant.fromJson(restaurant.toJson());
    source.addressEntries = [...addresses];
    final result = await Navigator.push<RestaurantVisitDraft>(
      context,
      MaterialPageRoute<RestaurantVisitDraft>(
        builder: (_) => RestaurantVisitEditor(
          restaurant: source,
          visit: visit,
          draftOnly: true,
          onPhotosSelected: widget.selections.addAll,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      addresses
        ..clear()
        ..addAll(result.addresses);
      if (visit == null) {
        draft.records.add(result.visit);
      } else {
        draft.records[draft.records.indexOf(visit)] = result.visit;
      }
    });
  }

  Future<void> leave() async {
    if (busy) return;
    if (draft.records.isNotEmpty &&
        !await confirmAction(
          context,
          title: '放弃本次消费记录？',
          message: '未保存的消费记录将不会保留。',
          confirmLabel: '放弃',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context);
  }

  Future<void> save() async {
    final missing = draft.records
        .where((visit) => visit.addressId.isEmpty)
        .firstOrNull;
    if (missing != null) {
      showToast(context, '请选择这次用餐的分店');
      await edit(missing);
      return;
    }
    setState(() => busy = true);
    final store = MenuScope.of(context);
    final saved = await performAction(context, () async {
      final prepared = await draft.prepare(store);
      await store.update(MenuWriteScope.restaurant(widget.restaurantId), (
        data,
      ) {
        final target = data.restaurants.firstWhere(
          (r) => r.id == widget.restaurantId,
        );
        final mapped = <String, RestaurantAddress>{};
        for (final address in addresses) {
          final existing =
              target.addressEntries
                  .where((a) => a.id == address.id)
                  .firstOrNull ??
              target.addressEntries
                  .where((a) => a.fullAddress == address.fullAddress)
                  .firstOrNull;
          mapped[address.id] = existing ?? address;
          if (existing == null) target.addressEntries.add(address);
        }
        for (final visit in prepared) {
          final address = mapped[visit.addressId]!;
          visit.addressId = address.id;
          visit.address = address.fullAddress;
        }
        target.addresses = target.addressEntries
            .map((a) => a.fullAddress)
            .toList();
        target.records.addAll(prepared);
      });
    });
    if (!mounted) return;
    if (saved) {
      showToast(context, '消费记录已保存');
      setState(() => leaving = true);
      Navigator.pop(context);
    } else {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('确认消费记录'),
        leading: IconButton(
          onPressed: busy ? null : leave,
          icon: const MenuIcon(Icons.arrow_back),
        ),
        actions: [
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
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              restaurant.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            RestaurantRecordSection(
              records: draft.records,
              onAdd: () => edit(null),
              onPhotos: pick,
              onEdit: edit,
              onDish: (visit, _) => edit(visit),
              onRemove: (visit) => setState(() => draft.records.remove(visit)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: busy || draft.records.isEmpty ? null : save,
          child: Text(busy ? '正在处理' : '保存消费记录'),
        ),
      ),
    ),
  );
}
