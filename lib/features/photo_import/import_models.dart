import 'dart:io';
import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import '../../core/models.dart';

enum ImportPhotoKind { environment, dish }

class ImportPhoto {
  ImportPhoto({
    required this.path,
    this.date,
    this.latitude,
    this.longitude,
    this.addressId = '',
    this.kind = ImportPhotoKind.environment,
    this.name = '',
    this.price = 0,
    this.quantity = 1,
  });
  final String path;
  DateTime? date;
  final double? latitude;
  final double? longitude;
  String addressId;
  ImportPhotoKind kind;
  String name;
  double price;
  int quantity;
  ImportPhoto copy() => ImportPhoto(
    path: path,
    date: date,
    latitude: latitude,
    longitude: longitude,
    addressId: addressId,
    kind: kind,
    name: name,
    price: price,
    quantity: quantity,
  );
}

Future<ImportPhoto> readImportPhoto(String path) async {
  try {
    final tags = await readExifFromFile(File(path), details: false);
    return ImportPhoto(
      path: path,
      date: _captureTime(tags['EXIF DateTimeOriginal']?.printable),
      latitude: _coordinate(
        tags['GPS GPSLatitude'],
        tags['GPS GPSLatitudeRef']?.printable,
        true,
      ),
      longitude: _coordinate(
        tags['GPS GPSLongitude'],
        tags['GPS GPSLongitudeRef']?.printable,
        false,
      ),
    );
  } catch (error, stack) {
    debugPrint('Photo metadata could not be read: $error\n$stack');
    // A photo without readable metadata remains available for manual setup.
    return ImportPhoto(path: path);
  }
}

DateTime? _captureTime(String? raw) {
  if (raw == null) return null;
  final match = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$',
  ).firstMatch(raw.trim());
  if (match == null) return null;
  final values = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  if (values[0] < 1900 || values[0] > 2100) return null;
  final date = DateTime(
    values[0],
    values[1],
    values[2],
    values[3],
    values[4],
    values[5],
  );
  if (date.year != values[0] ||
      date.month != values[1] ||
      date.day != values[2] ||
      date.hour != values[3] ||
      date.minute != values[4] ||
      date.second != values[5]) {
    return null;
  }
  return date;
}

double? _coordinate(IfdTag? tag, String? ref, bool latitude) {
  if (tag == null || tag.values is! IfdRatios || ref == null) return null;
  final values = (tag.values as IfdRatios).ratios;
  if (values.length != 3 || values.any((v) => v.denominator == 0)) return null;
  final direction = ref.trim();
  if (latitude
      ? direction != 'N' && direction != 'S'
      : direction != 'E' && direction != 'W') {
    return null;
  }
  final value =
      values[0].toDouble() +
      values[1].toDouble() / 60 +
      values[2].toDouble() / 3600;
  if (!value.isFinite || value < 0 || value > (latitude ? 90 : 180)) {
    return null;
  }
  return direction == 'S' || direction == 'W' ? -value : value;
}

class ImportVisit {
  ImportVisit({
    required this.date,
    required this.address,
    required this.photos,
    required this.items,
    required this.environments,
  });
  DateTime date;
  RestaurantAddress address;
  List<ImportPhoto> photos;
  List<VisitDish> items;
  List<String> environments;
  bool separateDishesConfirmed = false;
  bool get duplicateDishes =>
      items.map((i) => i.name).toSet().length != items.length;
  double get total => items.fold(0.0, (sum, item) => sum + item.cost);
}

List<ImportVisit> groupImportPhotos(
  List<ImportPhoto> source,
  List<RestaurantAddress> addresses,
) {
  final photos = [...source]..sort((a, b) => a.date!.compareTo(b.date!));
  final groups = <ImportVisit>[];
  for (final photo in photos) {
    final date = photo.date!;
    final group = groups
        .where(
          (g) =>
              g.address.id == photo.addressId &&
              g.date.year == date.year &&
              g.date.month == date.month &&
              g.date.day == date.day &&
              date.difference(g.date) <= const Duration(hours: 3),
        )
        .lastOrNull;
    final target =
        group ??
        ImportVisit(
          date: date,
          address: addresses.firstWhere((a) => a.id == photo.addressId),
          photos: [],
          items: [],
          environments: [],
        );
    if (group == null) groups.add(target);
    target.photos.add(photo);
    if (photo.kind == ImportPhotoKind.environment) {
      target.environments.add(photo.path);
    } else {
      target.items.add(
        VisitDish(
          dishId: '',
          name: photo.name,
          price: photo.price,
          quantity: photo.quantity,
          imagePaths: [photo.path],
        ),
      );
    }
  }
  return groups;
}

ImportVisit importVisitFromPhotos(
  List<ImportPhoto> source,
  RestaurantAddress address,
) {
  final photos = [...source]..sort((a, b) => a.date!.compareTo(b.date!));
  return ImportVisit(
    date: photos.first.date!,
    address: address,
    photos: photos,
    items: [
      for (final photo in photos)
        if (photo.kind == ImportPhotoKind.dish)
          VisitDish(
            dishId: '',
            name: photo.name,
            price: photo.price,
            quantity: photo.quantity,
            imagePaths: [photo.path],
          ),
    ],
    environments: [
      for (final photo in photos)
        if (photo.kind == ImportPhotoKind.environment) photo.path,
    ],
  );
}
