import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/geo_point.dart';
import '../../core/models.dart';
import '../../ui/widgets.dart';

class RestaurantDistance {
  const RestaurantDistance(this.address, this.meters);
  final RestaurantAddress address;
  final double meters;
  String get label => meters < 1000
      ? '${meters.round()}米'
      : '${(meters / 1000).toStringAsFixed(1)}公里';
}

RestaurantDistance? nearestRestaurantAddress(
  Iterable<RestaurantAddress> addresses,
  GeoPoint origin,
) {
  RestaurantDistance? nearest;
  for (final address in addresses) {
    final point = address.location;
    if (point == null) continue;
    final meters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      point.latitude,
      point.longitude,
    );
    if (nearest == null || meters < nearest.meters) {
      nearest = RestaurantDistance(address, meters);
    }
  }
  return nearest;
}

Future<GeoPoint?> locateForRestaurantSort(BuildContext context) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (context.mounted) showToast(context, '请先开启手机定位服务');
    return null;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    if (context.mounted) showToast(context, '请在系统设置中允许随机菜单获取位置');
    return null;
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: Platform.isAndroid
        ? AndroidSettings(
            forceLocationManager: true,
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 20),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
  );
  return GeoPoint(latitude: position.latitude, longitude: position.longitude);
}
