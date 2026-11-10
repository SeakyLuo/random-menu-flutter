part of 'menu_database.dart';

typedef RestaurantDetailsResult = ({
  Restaurant restaurant,
  List<String> categories,
  Map<String, String> categoryIds,
  Map<String, String> changedAddresses,
});

Future<RestaurantDetailsResult> _editRestaurantDetails(
  Database database, {
  required Map<String, dynamic> before,
  required Restaurant details,
  required bool updateFavorite,
}) async {
  final timeline = TimelineTask()..start('restaurant.saveDetails');
  try {
    return await database.transaction((txn) async {
      timeline.instant('read.start');
      final reads = txn.batch();
      reads.query('restaurants', where: 'id = ?', whereArgs: [details.id]);
      reads.query(
        'restaurant_addresses',
        where: 'restaurant_id = ?',
        whereArgs: [details.id],
        orderBy: 'position',
      );
      reads.query('restaurant_categories', orderBy: 'position');
      reads.query(
        'favorites',
        where: 'target_type = ? AND target_id = ?',
        whereArgs: ['restaurant', details.id],
      );
      reads.query(
        'restaurant_visits',
        columns: ['address_id'],
        where: 'restaurant_id = ?',
        whereArgs: [details.id],
        distinct: true,
      );
      reads.query(
        'restaurant_category_links',
        where: 'restaurant_id = ?',
        whereArgs: [details.id],
        orderBy: 'position',
      );
      final results = await reads.commit();
      timeline.instant('read.end');
      List<Map<String, Object?>> rows(int index) =>
          List<Map<String, Object?>>.from(results[index] as List);
      final row = rows(0).firstOrNull;
      final oldAddresses = rows(1);
      final categories = rows(2);
      final categoryNames = {
        for (final category in categories) category['id']: category['name'],
      };
      final favorite = rows(3).isNotEmpty;
      final current = row == null
          ? null
          : Restaurant(
              id: details.id,
              name: row['name'] as String,
              categories: [
                for (final link in rows(5))
                  categoryNames[link['category_id']]! as String,
              ],
              note: row['note'] as String,
              link: row['link'] as String,
              addresses: List<String>.from(
                jsonDecode(row['addresses'] as String) as List,
              ),
              addressEntries: [
                for (final address in oldAddresses)
                  RestaurantAddress.fromJson({
                    'id': address['id'],
                    'province': address['province'],
                    'city': address['city'],
                    'county': address['county'],
                    'detail': address['detail'],
                    'location': address['latitude'] == null
                        ? null
                        : {
                            'latitude': address['latitude'],
                            'longitude': address['longitude'],
                          },
                  }),
              ],
              favorite: favorite,
              coverDishId: row['cover_dish_id'] as String?,
            );
      requireUnchangedRecord(
        before,
        current?.toJson(includeRecords: false),
        ignored: {'coverDishId', if (!updateFavorite) 'favorite'},
      );
      final addressIds = details.addressEntries
          .map((address) => address.id)
          .toSet();
      if (rows(4).any(
        (visit) =>
            visit['address_id'] != '' &&
            !addressIds.contains(visit['address_id']),
      )) {
        throw StateError('已有消费记录使用这个地址，请先修改或删除相关消费记录');
      }
      final categoryIds = {
        for (final category in categories)
          category['name'] as String: category['id'] as String,
      };
      final listed = [
        for (final category in categories)
          if (category['listed'] == 1) category['name'] as String,
      ];
      final writes = txn.batch();
      var nextCategoryPosition = categories.isEmpty
          ? 0
          : (categories.last['position'] as int) + 1;
      final categoryPaths = {
        for (final tag in details.categories) ...tagPathPrefixes(tag),
      };
      for (final category in categoryPaths) {
        if (listed.contains(category)) continue;
        if (categoryIds.containsKey(category)) {
          writes.update(
            'restaurant_categories',
            {'listed': 1},
            where: 'id = ?',
            whereArgs: [categoryIds[category]],
          );
        } else {
          final id = newId();
          categoryIds[category] = id;
          writes.insert('restaurant_categories', {
            'id': id,
            'name': category,
            'position': nextCategoryPosition++,
            'listed': 1,
          });
        }
        listed.add(category);
      }
      writes.delete(
        'restaurant_category_links',
        where: 'restaurant_id = ?',
        whereArgs: [details.id],
      );
      for (final (position, category) in details.categories.toSet().indexed) {
        writes.insert('restaurant_category_links', {
          'restaurant_id': details.id,
          'position': position,
          'category_id': categoryIds[category],
        });
      }
      writes.update(
        'restaurants',
        {
          'name': details.name,
          'note': details.note,
          'link': details.link,
          'addresses': jsonEncode(
            details.addressEntries
                .map((address) => address.fullAddress)
                .toList(),
          ),
        },
        where: 'id = ?',
        whereArgs: [details.id],
      );
      final oldById = {
        for (final address in oldAddresses) address['id']: address,
      };
      final oldText = {
        for (final address in current!.addressEntries)
          address.id: address.fullAddress,
      };
      final changedAddresses = <String, String>{};
      for (final old in oldAddresses) {
        if (!addressIds.contains(old['id'])) {
          writes.delete(
            'restaurant_addresses',
            where: 'restaurant_id = ? AND id = ?',
            whereArgs: [details.id, old['id']],
          );
        }
      }
      for (final (position, address) in details.addressEntries.indexed) {
        final next = <String, Object?>{
          'restaurant_id': details.id,
          'id': address.id,
          'position': position,
          'province': address.province,
          'city': address.city,
          'county': address.county,
          'detail': address.detail,
          'latitude': address.location?.latitude,
          'longitude': address.location?.longitude,
        };
        final old = oldById[address.id];
        if (old == null) {
          writes.insert('restaurant_addresses', next);
        } else if (!_sameRow(old, next)) {
          writes.update(
            'restaurant_addresses',
            next,
            where: 'restaurant_id = ? AND id = ?',
            whereArgs: [details.id, address.id],
          );
        }
        if (old != null && oldText[address.id] != address.fullAddress) {
          changedAddresses[address.id] = address.fullAddress;
          writes.update(
            'restaurant_visits',
            {'address': address.fullAddress},
            where: 'restaurant_id = ? AND address_id = ?',
            whereArgs: [details.id, address.id],
          );
        }
      }
      if (updateFavorite && details.favorite != favorite) {
        if (details.favorite) {
          writes.insert('favorites', {
            'target_type': 'restaurant',
            'target_id': details.id,
          });
        } else {
          writes.delete(
            'favorites',
            where: 'target_type = ? AND target_id = ?',
            whereArgs: ['restaurant', details.id],
          );
        }
      }
      timeline.instant('commit.start');
      await writes.commit(noResult: true);
      timeline.instant('commit.end');
      return (
        restaurant: Restaurant(
          id: details.id,
          name: details.name,
          categories: [...details.categories],
          note: details.note,
          link: details.link,
          favorite: updateFavorite ? details.favorite : favorite,
          coverDishId: current.coverDishId,
          addressEntries: details.addressEntries,
          addresses: details.addressEntries
              .map((address) => address.fullAddress)
              .toList(),
        ),
        categories: listed,
        categoryIds: categoryIds,
        changedAddresses: changedAddresses,
      );
    });
  } finally {
    timeline.finish();
  }
}
