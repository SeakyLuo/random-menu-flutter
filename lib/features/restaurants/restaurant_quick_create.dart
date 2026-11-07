import '../../core/models.dart';
import '../../core/photo_location.dart';
import '../photo_import/import_models.dart';

class RestaurantQuickDraft {
  final addresses = <RestaurantAddress>[];
  final records = <Visit>[];
  bool missingDates = false;
}

Future<RestaurantQuickDraft> buildRestaurantFromPhotos(
  List<String> paths,
) async {
  final photos = <ImportPhoto>[];
  for (var offset = 0; offset < paths.length; offset += 8) {
    photos.addAll(
      await Future.wait(paths.skip(offset).take(8).map(readImportPhoto)),
    );
  }
  final coordinates = photos
      .where((photo) => photo.latitude != null && photo.longitude != null)
      .map((photo) => (photo.latitude!, photo.longitude!))
      .toSet()
      .toList();
  final locations = <(double, double), RestaurantAddress?>{};
  for (var offset = 0; offset < coordinates.length; offset += 4) {
    final batch = coordinates.skip(offset).take(4).toList();
    final resolved = await Future.wait(
      batch.map((point) => resolvePhotoAddress(point.$1, point.$2)),
    );
    for (var i = 0; i < batch.length; i++) {
      locations[batch[i]] = resolved[i];
    }
  }
  final draft = RestaurantQuickDraft();
  final addresses = <String, RestaurantAddress>{};
  final now = DateTime.now();
  photos.sort((a, b) => (a.date ?? now).compareTo(b.date ?? now));
  for (final photo in photos) {
    final resolved = locations[(photo.latitude, photo.longitude)];
    RestaurantAddress? address;
    if (resolved != null) {
      address = addresses.putIfAbsent(resolved.fullAddress, () => resolved);
    }
    final date = photo.date ?? now;
    if (photo.date == null) draft.missingDates = true;
    final record = draft.records.reversed.where((record) {
      if (record.addressId != (address?.id ?? '')) return false;
      final sameDay =
          record.date.year == date.year &&
          record.date.month == date.month &&
          record.date.day == date.day;
      return sameDay ||
          record.date.difference(date).abs() <= const Duration(hours: 3);
    }).firstOrNull;
    final dish = VisitDish(dishId: '', name: '', imagePaths: [photo.path]);
    if (record == null) {
      draft.records.add(
        Visit(
          id: newId(),
          date: date,
          addressId: address?.id ?? '',
          address: address?.fullAddress ?? '',
          autoCost: true,
          items: [dish],
        ),
      );
    } else {
      record.items.add(dish);
      if (date.isBefore(record.date)) record.date = date;
    }
  }
  draft.addresses.addAll(addresses.values);
  return draft;
}
