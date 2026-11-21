import 'package:flutter/material.dart';
import '../../core/geo_point.dart';
import '../../ui/menu_dialog.dart';
import '../../ui/widgets.dart';

Future<GeoPoint?> editRestaurantGps(BuildContext context, GeoPoint? location) =>
    showDialog<GeoPoint>(
      context: context,
      builder: (_) => _RestaurantGpsDialog(location: location),
    );

class _RestaurantGpsDialog extends StatefulWidget {
  const _RestaurantGpsDialog({required this.location});

  final GeoPoint? location;

  @override
  State<_RestaurantGpsDialog> createState() => _RestaurantGpsDialogState();
}

class _RestaurantGpsDialogState extends State<_RestaurantGpsDialog> {
  late final _latitude = TextEditingController(
    text: widget.location?.latitude.toString(),
  );
  late final _longitude = TextEditingController(
    text: widget.location?.longitude.toString(),
  );

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _confirm() {
    final latitude = double.tryParse(_latitude.text);
    if (latitude == null || !latitude.isFinite || latitude.abs() > 90) {
      showToast(context, '请输入 -90 到 90 之间的纬度');
      return;
    }
    final longitude = double.tryParse(_longitude.text);
    if (longitude == null || !longitude.isFinite || longitude.abs() > 180) {
      showToast(context, '请输入 -180 到 180 之间的经度');
      return;
    }
    Navigator.pop(context, GeoPoint(latitude: latitude, longitude: longitude));
  }

  @override
  Widget build(BuildContext context) {
    const keyboardType = TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    );
    return MenuDialog(
      title: '修改 GPS',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _latitude,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '纬度'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _longitude,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirm(),
            decoration: const InputDecoration(labelText: '经度'),
          ),
        ],
      ),
      actions: Row(
        children: [
          Expanded(
            child: MenuDialogButton(
              label: '取消',
              role: MenuDialogRole.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MenuDialogButton(label: '确定', onPressed: _confirm),
          ),
        ],
      ),
    );
  }
}
