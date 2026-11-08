import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'photo_location.dart';

class CurrentCity {
  static const _lifetime = Duration(minutes: 5);
  static String? _city;
  static DateTime? _updated;
  static Future<String?>? _pending;

  static String? get cached =>
      _updated != null && DateTime.now().difference(_updated!) < _lifetime
      ? _city
      : null;

  static Future<String?> resolve() {
    final city = cached;
    if (city != null) return Future.value(city);
    return _pending ??= _locate().whenComplete(() => _pending = null);
  }

  static Future<String?> _locate() async {
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: Platform.isAndroid
          ? AndroidSettings(
              forceLocationManager: true,
              accuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 10),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
    );
    final address = await resolveAddressAt(
      position.latitude,
      position.longitude,
    );
    if (address == null || address.city.isEmpty) return null;
    _city = address.city;
    _updated = DateTime.now();
    return _city;
  }
}
