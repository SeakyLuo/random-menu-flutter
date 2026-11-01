import 'package:flutter/services.dart';
import 'models.dart';

const _locationChannel = MethodChannel(
  'com.seakyluo.random_menu/photo_location',
);

// Called only after the user asks to identify a selected photo's location.
Future<RestaurantAddress?> resolvePhotoAddress(
  double latitude,
  double longitude,
) async {
  final address = await _locationChannel.invokeMapMethod<String, dynamic>(
    'reverseGeocode',
    {'latitude': latitude, 'longitude': longitude},
  );
  if (address == null) return null;
  return RestaurantAddress(
    id: newId(),
    province: address['province'] as String,
    city: address['city'] as String,
    county: address['county'] as String,
    detail: address['detail'] as String,
  );
}
