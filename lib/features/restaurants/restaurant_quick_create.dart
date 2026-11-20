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
  final draft = RestaurantQuickDraft();
  final now = DateTime.now();
  photos.sort((a, b) => (a.date ?? now).compareTo(b.date ?? now));
  final groups = <List<ImportPhoto>>[];
  for (final photo in photos) {
    if (photo.date == null) draft.missingDates = true;
    final date = photo.date ?? now;
    if (groups.isEmpty ||
        date.difference(groups.last.first.date ?? now) >
            const Duration(hours: 3)) {
      groups.add([photo]);
    } else {
      groups.last.add(photo);
    }
  }

  final coordinates = [
    for (final group in groups)
      group
          .where((photo) => photo.latitude != null && photo.longitude != null)
          .map((photo) => (photo.latitude!, photo.longitude!))
          .firstOrNull,
  ];
  final points = coordinates.whereType<(double, double)>().toSet().toList();
  final locations = <(double, double), RestaurantAddress?>{};
  for (var offset = 0; offset < points.length; offset += 4) {
    final batch = points.skip(offset).take(4).toList();
    final resolved = await Future.wait(
      batch.map((point) => resolvePhotoAddress(point.$1, point.$2)),
    );
    for (var i = 0; i < batch.length; i++) {
      locations[batch[i]] = resolved[i];
    }
  }

  final addresses = <String, RestaurantAddress>{};
  for (var i = 0; i < groups.length; i++) {
    final group = groups[i];
    final resolved = locations[coordinates[i]];
    final address = resolved == null
        ? null
        : addresses.putIfAbsent(resolved.fullAddress, () => resolved);
    draft.records.add(
      Visit(
        id: newId(),
        date: group.first.date ?? now,
        addressId: address?.id ?? '',
        address: address?.fullAddress ?? '',
        autoCost: true,
        items: [
          for (final photo in group)
            VisitDish(dishId: newId(), name: '', imagePaths: [photo.path]),
        ],
      ),
    );
  }
  draft.addresses.addAll(addresses.values);
  return draft;
}
