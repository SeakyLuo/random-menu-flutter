import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/menu_store.dart';
import '../../core/models.dart';
import 'menu_mcp_sql_tools.dart';

/// The MCP adapter edits the same atomic store used by the Flutter editors.
class MenuMcpTools {
  MenuMcpTools(this.store);
  final MenuStore store;

  static const _text = {'type': 'string'};
  static const _strings = {'type': 'array', 'items': _text, 'maxItems': 100};
  static const _flag = {'type': 'boolean'};
  static const _number = {'type': 'number', 'minimum': 0};
  static const _address = {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': '修改已有地址时必须原样传入其 id；新增地址省略'},
      'province': _text,
      'city': _text,
      'county': _text,
      'detail': _text,
    },
    'required': <String>[],
    'additionalProperties': false,
  };
  static const _item = {
    'type': 'object',
    'properties': {
      'dishId': {
        'type': 'string',
        'description': '修改已有菜品时必须原样传入其 dishId；新增菜品省略',
      },
      'name': _text,
      'price': _number,
      'packageId': {
        'type': ['string', 'null'],
        'description':
            '本次套餐 id；null 表示单点。套餐由 create/update_visit 的 packages 创建后取得。',
      },
      'quantity': {'type': 'integer', 'minimum': 1},
      'note': _text,
    },
    'required': <String>[],
    'additionalProperties': false,
  };

  static Map<String, Object?> _fields(String kind) => switch (kind) {
    'recipe' => {
      'name': _text,
      'note': {..._text, 'description': '完整菜谱正文，可写食材、用量和步骤；未知内容不要编造。'},
      'tags': {..._strings, 'maxItems': 10},
      'favorite': _flag,
    },
    'restaurant' => {
      'name': _text,
      'category': _text,
      'note': _text,
      'link': _text,
      'favorite': _flag,
      'addresses': {
        'type': 'array',
        'items': _address,
        'maxItems': 30,
        'description': '传入时整体替换分店列表，保留的已有分店带 id；已有探店记录引用的地址不能移除。',
      },
    },
    'visit' => {
      'addressId': {..._text, 'description': '已有餐厅地址的 id，可由 get_restaurant 查询'},
      'autoCost': _flag,
      'date': {..._text, 'description': 'ISO 8601 到店日期'},
      'totalCost': _number,
      'currency': {
        'type': 'string',
        'enum': MenuCurrency.values.map((c) => c.code).toList(),
        'description': '本次消费币种，默认 CNY；菜品、套餐和用券金额均使用此币种，不换算汇率。',
      },
      'address': _text,
      'note': _text,
      'companions': _strings,
      'packages': {
        'type': 'array',
        'maxItems': 100,
        'description':
            '整体替换本次套餐。新增省略 id，修改保留原 id；删除时同时解除其 items.packageId。每个套餐总价仅计一次，不重复计算成员菜价。',
        'items': {
          'type': 'object',
          'properties': {'id': _text, 'name': _text, 'totalPrice': _number},
          'required': ['name', 'totalPrice'],
          'additionalProperties': false,
        },
      },
      'coupons': {
        'type': 'array',
        'maxItems': 100,
        'description':
            '整体替换用券列表，按列表顺序依次抵扣，每张券按抵扣前余额判断门槛。type=amount：discount为单张减额，quantity为张数；type=percentage：rate为几折（如8.8），quantity必须1，maxDiscount为优惠上限可空。实付由autoCost决定是否自动计算。',
        'items': {
          'type': 'object',
          'properties': {
            'threshold': {
              'type': ['number', 'null'],
              'minimum': 0.01,
            },
            'type': {
              'type': 'string',
              'enum': ['amount', 'percentage'],
            },
            'rate': {
              'type': ['number', 'null'],
              'exclusiveMinimum': 0,
              'exclusiveMaximum': 10,
            },
            'maxDiscount': {
              'type': ['number', 'null'],
              'minimum': 0.01,
            },
            'discount': {
              'type': ['number', 'null'],
              'minimum': 0.01,
            },
            'quantity': {'type': 'integer', 'minimum': 1, 'maximum': 100},
          },
          'required': ['type', 'quantity'],
          'additionalProperties': false,
        },
      },
      'items': {
        'type': 'array',
        'items': _item,
        'maxItems': 100,
        'description': '传入时整体替换点单列表；需保留的已有条目带 dishId。条目未提供的字段和照片保留。',
      },
    },
    _ => throw ArgumentError.value(kind),
  };

  List<Map<String, Object?>> get definitions => [
    ...MenuMcpSqlTools.definitions,
    for (final kind in ['recipe', 'restaurant', 'visit'])
      for (final action in ['list', 'get', 'create', 'update', 'delete'])
        _definition(kind, action),
  ];

  Map<String, Object?> _definition(String kind, String action) {
    final title = {'recipe': '菜谱', 'restaurant': '餐厅', 'visit': '探店记录'}[kind]!;
    final verb = {
      'list': '搜索',
      'get': '查看',
      'create': '新增',
      'update': '修改',
      'delete': '删除',
    }[action]!;
    return {
      'name': '${action}_$kind',
      'title': '$verb$title',
      'description':
          '$verb$title。'
          '${kind == 'visit' ? '探店记录属于餐厅，先搜索餐厅取得 restaurantId。' : ''}'
          '${action == 'update' ? '仅更新提供的字段，保留照片和其他未提供字段；先 get 读取最新记录。' : ''}'
          '${action == 'delete' && kind == 'restaurant' ? '删除餐厅同时删除其全部探店记录，请先向用户确认。' : ''}'
          '${action == 'create' ? '保存正式记录，不是临时草稿。不要把未提供的事实当成真实内容。' : ''}',
      'annotations': {
        'readOnlyHint': action == 'list' || action == 'get',
        'destructiveHint': action == 'delete',
        'openWorldHint': false,
      },
      'inputSchema': {
        'type': 'object',
        'properties': {
          if (kind == 'visit') 'restaurantId': _text,
          if (action == 'list') ...{
            'query': _text,
            'offset': {'type': 'integer', 'minimum': 0},
            'limit': {'type': 'integer', 'minimum': 1, 'maximum': 50},
          } else if (action != 'create')
            'id': _text,
          if (action == 'update' || action == 'delete')
            'expectedVersion': {
              ..._text,
              'description': '从 get 返回的 version 原样传入，防止覆盖用户刚修改的记录。',
            },
          if (action == 'create' || action == 'update') ..._fields(kind),
        },
        'required': [
          if (kind == 'visit') 'restaurantId',
          if (action == 'list') ...[
            'query',
            'offset',
            'limit',
          ] else if (action != 'create')
            'id',
          if (action == 'update' || action == 'delete') 'expectedVersion',
          if (action == 'create') kind == 'visit' ? 'date' : 'name',
        ],
        'additionalProperties': false,
      },
    };
  }

  Future<Map<String, Object?>> call(
    String name,
    Map<String, dynamic> args,
  ) async {
    final definition = definitions.where((d) => d['name'] == name).firstOrNull;
    if (definition == null) throw ArgumentError('Unknown tool: $name');
    final schema = definition['inputSchema'] as Map;
    _validate(args, schema);
    if (MenuMcpSqlTools.names.contains(name)) {
      return MenuMcpSqlTools(store).call(name, args);
    }
    final split = name.indexOf('_');
    final action = name.substring(0, split), kind = name.substring(split + 1);
    List<Map<String, dynamic>> records(MenuData data) => switch (kind) {
      'recipe' => data.recipes.map((x) => x.toJson()).toList(),
      'restaurant' => data.restaurants.map((x) => x.toJson()).toList(),
      'visit' => _restaurant(
        data,
        args['restaurantId'] as String,
      ).records.map((x) => x.toJson()).toList(),
      _ => throw ArgumentError.value(kind),
    };
    if (action == 'list' || action == 'get') {
      await store.reload(
        scope: kind == 'visit'
            ? MenuWriteScope.restaurant(args['restaurantId'] as String)
            : kind == 'recipe'
            ? action == 'get'
                  ? MenuWriteScope.recipe(args['id'] as String)
                  : MenuWriteScope.recipesAll
            : action == 'get'
            ? MenuWriteScope.restaurant(args['id'] as String)
            : MenuWriteScope.restaurantsAll,
      );
    }
    final inferredTags =
        kind == 'recipe' && action == 'create' && !args.containsKey('tags')
        ? await store.data.inferRecipeTags(_name(args['name']))
        : <String>[];
    if (action == 'list') {
      final query = (args['query'] as String).toLowerCase();
      final found = records(store.data)
          .where(
            (r) =>
                '${r['name'] ?? ''} ${r['note']} ${r['tags'] ?? ''} ${r['address'] ?? ''}'
                    .toLowerCase()
                    .contains(query),
          )
          .toList();
      final offset = args['offset'] as int, limit = args['limit'] as int;
      final page = found.skip(offset).take(limit).toList();
      return {
        'records': [
          for (final r in page)
            {
              'id': r['id'],
              if (r.containsKey('name')) 'name': r['name'],
              if (kind == 'recipe') 'tags': r['tags'],
              if (kind == 'visit') ...{
                'date': r['date'],
                'totalCost': r['totalCost'],
                'currency': r['currency'],
              },
              if (kind == 'restaurant') ...{
                'category': r['category'],
                'visitCount': (r['records'] as List).length,
              },
            },
        ],
        'total': found.length,
        'nextOffset': offset + page.length < found.length
            ? offset + page.length
            : null,
      };
    }
    if (action == 'get') {
      final record = _record(records(store.data), args['id'] as String);
      return {
        'record': kind == 'restaurant'
            ? ({...record}..remove('records'))
            : record,
        'version': version(record),
        if (kind == 'restaurant')
          'visitCount': (record['records'] as List).length,
      };
    }
    final recordId = action == 'create' ? newId() : args['id'] as String;
    Map<String, dynamic>? saved;
    await store.update(
      kind == 'visit'
          ? MenuWriteScope.restaurant(args['restaurantId'] as String)
          : kind == 'recipe'
          ? MenuWriteScope.recipe(recordId)
          : MenuWriteScope.restaurant(recordId),
      (data) {
        final old = action == 'create'
            ? null
            : _record(records(data), args['id'] as String);
        if (old != null && args['expectedVersion'] != version(old)) {
          throw StateError(
            'Record changed. Read it again before editing or deleting.',
          );
        }
        final id = recordId;
        if (action == 'delete') {
          switch (kind) {
            case 'recipe':
              data.recipes.removeWhere((r) => r.id == id);
              data.selectedMenu.remove(id);
              if (data.recipeDraftSourceId == id) {
                data.recipeDraftSourceId = null;
              }
            case 'restaurant':
              data.restaurants.removeWhere((r) => r.id == id);
            case 'visit':
              _restaurant(
                data,
                args['restaurantId'] as String,
              ).records.removeWhere((r) => r.id == id);
          }
          return;
        }
        switch (kind) {
          case 'recipe':
            if ((old == null || args.containsKey('name')) &&
                data.recipes.any((r) => r.id != id && r.name == args['name'])) {
              throw StateError('同名菜谱已存在，请先查询并修改已有菜谱。');
            }
            final recipe = old == null
                ? Recipe(
                    id: id,
                    name: args['name'] as String,
                    tags: inferredTags,
                  )
                : Recipe.fromJson(old);
            if (args.containsKey('name')) recipe.name = _name(args['name']);
            if (args.containsKey('note')) recipe.note = args['note'] as String;
            if (args.containsKey('tags')) {
              recipe.tags = List<String>.from(args['tags'] as List);
            }
            if (args.containsKey('favorite')) {
              recipe.favorite = args['favorite'] as bool;
            }
            data.recipes = [
              for (final r in data.recipes)
                if (r.id != id) r,
              recipe,
            ];
            data.recipeTags = {...data.recipeTags, ...recipe.tags}.toList();
            saved = recipe.toJson();
          case 'restaurant':
            final restaurant = old == null
                ? Restaurant(id: id, name: args['name'] as String)
                : Restaurant.fromJson(old);
            if (args.containsKey('name')) restaurant.name = _name(args['name']);
            if (args.containsKey('note')) {
              restaurant.note = args['note'] as String;
            }
            if (args.containsKey('category')) {
              restaurant.category = args['category'] as String;
            }
            if (args.containsKey('link')) {
              restaurant.link = args['link'] as String;
            }
            if (args.containsKey('favorite')) {
              restaurant.favorite = args['favorite'] as bool;
            }
            if (args.containsKey('addresses')) {
              restaurant.addressEntries = _addresses(
                restaurant,
                args['addresses'] as List,
              );
              restaurant.addresses = restaurant.addressEntries
                  .map((a) => a.fullAddress)
                  .toList();
            }
            data.restaurants = [
              for (final r in data.restaurants)
                if (r.id != id) r,
              restaurant,
            ];
            saved = restaurant.toJson();
          case 'visit':
            final restaurant = _restaurant(
              data,
              args['restaurantId'] as String,
            );
            final visit = old == null
                ? Visit(id: id, date: DateTime.parse(args['date'] as String))
                : Visit.fromJson(old);
            if (args.containsKey('date')) {
              visit.date = DateTime.parse(args['date'] as String);
            }
            if (args.containsKey('currency')) {
              visit.currency = MenuCurrency.fromCode(
                args['currency'] as String,
              );
            }
            if (args.containsKey('totalCost')) {
              visit.totalCost = (args['totalCost'] as num).toDouble();
              visit.autoCost = false;
            }
            if (args.containsKey('addressId')) {
              final entry = restaurant.addressEntries.firstWhere(
                (a) => a.id == args['addressId'],
              );
              visit.addressId = entry.id;
              visit.address = entry.fullAddress;
            } else if (args.containsKey('address')) {
              visit.address = args['address'] as String;
              visit.addressId = '';
            }
            if (args.containsKey('note')) visit.note = args['note'] as String;
            if (args.containsKey('companions')) {
              visit.companions = List<String>.from(args['companions'] as List);
            }
            if (args.containsKey('items')) {
              visit.items = _items(visit, args['items'] as List);
              visit.dishes = visit.items.map((i) => i.name).toList();
            }
            if (args.containsKey('packages')) {
              visit.packages = (args['packages'] as List).map((value) {
                final id = value['id'] as String?;
                if (id != null && !visit.packages.any((p) => p.id == id)) {
                  throw ArgumentError('Package does not belong to this visit.');
                }
                return VisitPackage(
                  id: id ?? newId(),
                  name: _name(value['name']),
                  totalPrice: (value['totalPrice'] as num).toDouble(),
                );
              }).toList();
            }
            visit.validatePackages();
            if (args.containsKey('autoCost')) {
              visit.autoCost = args['autoCost'] as bool;
            }
            if (args.containsKey('coupons')) {
              visit.coupons = (args['coupons'] as List)
                  .map((c) => VisitCoupon.fromJson(c as Map<String, dynamic>))
                  .toList();
            }
            if (visit.autoCost) {
              visit.totalCost = visit.bill.total;
            }
            restaurant.records = [
              for (final r in restaurant.records)
                if (r.id != id) r,
              visit,
            ];
            saved = visit.toJson();
        }
      },
    );
    return action == 'delete'
        ? {'deleted': true}
        : {
            'record': kind == 'restaurant'
                ? ({...saved!}..remove('records'))
                : saved,
            'version': version(saved!),
            if (kind == 'restaurant')
              'visitCount': (saved!['records'] as List).length,
          };
  }

  static List<RestaurantAddress> _addresses(
    Restaurant restaurant,
    List changes,
  ) {
    final result = <RestaurantAddress>[];
    for (final value in changes) {
      final id = value['id'] as String?;
      final address = id == null
          ? RestaurantAddress(id: newId())
          : RestaurantAddress.fromJson(
              restaurant.addressEntries.firstWhere((a) => a.id == id).toJson(),
            );
      if (value.containsKey('province')) {
        address.province = value['province'] as String;
      }
      if (value.containsKey('city')) address.city = value['city'] as String;
      if (value.containsKey('county')) {
        address.county = value['county'] as String;
      }
      if (value.containsKey('detail')) {
        address.detail = value['detail'] as String;
      }
      if (address.fullAddress.trim().isEmpty) {
        throw ArgumentError('Address must not be empty.');
      }
      if (result.any(
        (a) => a.id == address.id || a.fullAddress == address.fullAddress,
      )) {
        throw ArgumentError('Duplicate address.');
      }
      result.add(address);
    }
    if (restaurant.records.any(
      (v) => v.addressId.isNotEmpty && !result.any((a) => a.id == v.addressId),
    )) {
      throw StateError('已有探店记录使用这个地址，请保留该分店。');
    }
    return result;
  }

  static List<VisitDish> _items(Visit visit, List changes) {
    final result = <VisitDish>[];
    for (final value in changes) {
      final id = value['dishId'] as String?;
      final item = id == null
          ? VisitDish(dishId: newId(), name: _name(value['name']))
          : VisitDish.fromJson(
              visit.items.firstWhere((i) => i.dishId == id).toJson(),
            );
      if (value.containsKey('name')) item.name = _name(value['name']);
      if (value.containsKey('price')) {
        item.price = (value['price'] as num).toDouble();
      }
      if (value.containsKey('quantity')) {
        item.quantity = value['quantity'] as int;
      }
      if (value.containsKey('note')) item.note = value['note'] as String;
      if (value.containsKey('packageId')) {
        item.packageId = value['packageId'] as String?;
      }
      if (result.any((i) => i.dishId == item.dishId)) {
        throw ArgumentError('Duplicate dish.');
      }
      result.add(item);
    }
    return result;
  }

  // A content token detects changes made by both the UI and external clients.
  static String version(Map<String, dynamic> record) =>
      sha256.convert(utf8.encode(jsonEncode(record))).toString();
  static String _name(Object? value) {
    final name = value as String;
    if (name.trim().isEmpty) throw ArgumentError('Name must not be empty.');
    return name;
  }

  static Restaurant _restaurant(MenuData data, String id) =>
      data.restaurants.where((r) => r.id == id).firstOrNull ??
      (throw StateError('Restaurant not found: $id'));
  static Map<String, dynamic> _record(
    List<Map<String, dynamic>> records,
    String id,
  ) =>
      records.where((r) => r['id'] == id).firstOrNull ??
      (throw StateError('Record not found: $id'));

  static void _validate(Object? value, Map schema) {
    switch (schema['type']) {
      case ['number', 'null']:
        if (value == null) return;
        _validate(value, {...schema, 'type': 'number'});
      case ['string', 'null']:
        if (value == null) return;
        _validate(value, {...schema, 'type': 'string'});
      case 'object':
        if (value is! Map) throw ArgumentError('Expected an object.');
        final fields = schema['properties'] as Map;
        if (value.keys.any((k) => !fields.containsKey(k))) {
          throw ArgumentError('Unknown field.');
        }
        for (final key in schema['required'] as List) {
          if (!value.containsKey(key)) {
            throw ArgumentError('Missing field: $key');
          }
        }
        for (final entry in value.entries) {
          _validate(entry.value, fields[entry.key] as Map);
        }
      case 'string':
        if (value is! String) throw ArgumentError('Expected a string.');
      case 'boolean':
        if (value is! bool) throw ArgumentError('Expected a boolean.');
      case 'integer':
      case 'number':
        if (value is! num ||
            !value.isFinite ||
            (schema['type'] == 'integer' && value is! int)) {
          throw ArgumentError('Invalid number.');
        }
        if ((schema['minimum'] != null && value < (schema['minimum'] as num)) ||
            (schema['maximum'] != null && value > (schema['maximum'] as num))) {
          throw ArgumentError('Number out of range.');
        }
      case 'array':
        if (value is! List || value.length > (schema['maxItems'] as int)) {
          throw ArgumentError('Invalid list size.');
        }
        for (final item in value) {
          _validate(item, schema['items'] as Map);
        }
    }
  }
}
