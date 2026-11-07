#!/usr/bin/env python3
"""One-off offline rewrite of the previous 15-table database. No app migration."""
import argparse
import json
import re
import sqlite3
import uuid
from collections import defaultdict
from pathlib import Path


def rows(db, table, order='position'):
    return [dict(row) for row in db.execute(
        f'SELECT * FROM {table}' + (f' ORDER BY {order}' if order else ''))]


def previous_snapshot(db):
    data = json.loads(rows(db, 'menu_settings', None)[0]['payload'])
    data['recipes'] = [json.loads(row['payload']) for row in rows(db, 'recipes')]
    data['restaurants'] = [json.loads(row['payload']) for row in rows(db, 'restaurants')]
    favorites = {(row['target_type'], row['target_id']) for row in rows(db, 'favorites', None)}
    tags = defaultdict(list)
    for row in rows(db, 'recipe_tag_links', 'recipe_id, position'):
        tags[row['recipe_id']].append(row['tag'])
    data['recipeTags'] = [row['name'] for row in rows(db, 'recipe_tags')]
    for recipe in data['recipes']:
        recipe['favorite'] = ('recipe', recipe['id']) in favorites
        recipe['tags'] = tags[recipe['id']]
    branches, dishes, visits, items = (defaultdict(list) for _ in range(4))
    for row in rows(db, 'restaurant_addresses', 'restaurant_id, position'):
        branches[row['restaurant_id']].append({
            'id': row['id'], 'province': row['province'], 'city': row['city'],
            'county': row['county'], 'detail': row['detail'],
            'location': None if row['latitude'] is None else {
                'latitude': row['latitude'], 'longitude': row['longitude']}})
    def dish(row):
        return {'name': row['name'], 'price': row['price'], 'quantity': row['quantity'],
                'note': row['note'], 'imagePaths': json.loads(row['image_paths'])}
    for row in rows(db, 'restaurant_dishes', 'restaurant_id, position'):
        dishes[row['restaurant_id']].append({'id': row['id'], **dish(row)})
    for row in rows(db, 'restaurant_visit_items', 'restaurant_id, visit_id, position'):
        items[(row['restaurant_id'], row['visit_id'])].append({'dishId': row['dish_id'], **dish(row)})
    for row in rows(db, 'restaurant_visits', 'restaurant_id, position'):
        visits[row['restaurant_id']].append({
            'id': row['id'], 'date': row['date'], 'totalCost': row['total_cost'],
            'addressId': row['address_id'], 'address': row['address'], 'autoCost': bool(row['auto_cost']),
            'note': row['note'], 'companions': json.loads(row['companions']),
            'dishes': json.loads(row['dishes']), 'imagePaths': json.loads(row['image_paths']),
            'items': items[(row['restaurant_id'], row['id'])]})
    for restaurant in data['restaurants']:
        rid = restaurant['id']
        restaurant.update(favorite=('restaurant', rid) in favorites, addressEntries=branches[rid],
                          foods=dishes[rid], records=visits[rid])
    for table, field in [('to_cook', 'toCook'), ('to_eat', 'toEat'), ('dislikes', 'dislikes')]:
        data[field] = [row['name'] for row in rows(db, table)]
    values = defaultdict(list)
    for row in rows(db, 'auto_tag_rule_values', 'mode, rule_key, position'):
        values[(row['mode'], row['rule_key'])].append(row['value'])
    rules = {'literal': {}, 'pattern': {}}
    for row in rows(db, 'auto_tag_rules', 'mode, position'):
        rules[row['mode']][row['rule_key']] = values[(row['mode'], row['rule_key'])]
    data.update(tagRules=rules['literal'], patternTagRules=rules['pattern'])
    # The previous database may precede the separate category-management UI.
    if data['version'] == 2:
        data['version'] = 3
        data['restaurantCategories'] = list(dict.fromkeys(
            r['category'] for r in data['restaurants'] if r['category']))
    return data


def create_rows(data, source):
    result = {}
    tag_names = list(dict.fromkeys([*data['recipeTags'],
                                  *(tag for r in data['recipes'] for tag in r['tags'])]))
    category_names = list(dict.fromkeys([*data['restaurantCategories'],
                                       *(r['category'] for r in data['restaurants'] if r['category'])]))
    tags = {name: str(uuid.uuid4()) for name in tag_names}
    categories = {name: str(uuid.uuid4()) for name in category_names}
    result['recipe_tags'] = [dict(id=tags[name], name=name, position=i,
                                 listed=int(name in data['recipeTags'])) for i, name in enumerate(tag_names)]
    result['restaurant_categories'] = [dict(id=categories[name], name=name, position=i,
        listed=int(name in data['restaurantCategories'])) for i, name in enumerate(category_names)]
    result['recipes'] = [dict(id=r['id'], position=i, name=r['name'], note=r['note'],
        hidden_rounds=r['hiddenRounds'], created_at=r['createdAt']) for i, r in enumerate(data['recipes'])]
    result['restaurants'] = [dict(id=r['id'], position=i, name=r['name'], note=r['note'], link=r['link'],
        category_id=categories[r['category']] if r['category'] else None,
        addresses=json.dumps(r['addresses'], ensure_ascii=False)) for i, r in enumerate(data['restaurants'])]
    result['recipe_tag_links'] = [dict(recipe_id=r['id'], position=i, tag_id=tags[tag])
        for r in data['recipes'] for i, tag in enumerate(r['tags'])]
    for table, order in [('favorites', None), ('to_cook', 'position'), ('to_eat', 'position'),
                         ('dislikes', 'position'), ('auto_tag_rules', 'mode, position'),
                         ('auto_tag_rule_values', 'mode, rule_key, position'),
                         ('restaurant_addresses', 'restaurant_id, position')]:
        result[table] = rows(source, table, order)
    result['restaurant_dishes'] = [{k: v for k, v in row.items() if k != 'image_paths'}
        for row in rows(source, 'restaurant_dishes', 'restaurant_id, position')]
    result['restaurant_visits'] = [{k: v for k, v in row.items() if k not in ('image_paths', 'companions')}
        for row in rows(source, 'restaurant_visits', 'restaurant_id, position')]
    result['restaurant_visit_items'] = [{k: v for k, v in row.items() if k != 'image_paths'}
        for row in rows(source, 'restaurant_visit_items', 'restaurant_id, visit_id, position')]
    result['visit_companions'] = [dict(restaurant_id=r['id'], visit_id=v['id'], position=i, name=name)
        for r in data['restaurants'] for v in r['records'] for i, name in enumerate(v['companions'])]
    result['search_history'] = [dict(search_type=kind, position=i, keyword=keyword)
        for kind, field in [('recipe', 'recipeSearchHistory'), ('restaurant', 'restaurantSearchHistory')]
        for i, keyword in enumerate(data[field])]
    images = []
    def add_images(kind, restaurant, owner, paths, item=-1):
        images.extend(dict(kind=kind, restaurant_id=restaurant, owner_id=owner, item_position=item,
                           position=i, path=path) for i, path in enumerate(paths))
    add_images('legacy', '', '', data['legacyImagePaths'])
    if data['recipeDraft'] is not None:
        add_images('draft', '', '', data['recipeDraft']['imagePaths'])
    for recipe in data['recipes']:
        add_images('recipe', '', recipe['id'], recipe['imagePaths'])
    for restaurant in data['restaurants']:
        rid = restaurant['id']
        for dish in restaurant['foods']:
            add_images('dish', rid, dish['id'], dish['imagePaths'])
        for visit in restaurant['records']:
            add_images('visit', rid, visit['id'], visit['imagePaths'])
            for i, dish in enumerate(visit['items']):
                add_images('item', rid, visit['id'], dish['imagePaths'], i)
    result['images'] = images
    settings = {key: data[key] for key in ['version', 'note', 'themeMode', 'autoTag', 'selectedMenu',
                                         'recipeDraftSourceId', 'recipeTagSort']}
    settings['recipeDraft'] = None if data['recipeDraft'] is None else {
        k: v for k, v in data['recipeDraft'].items() if k != 'imagePaths'}
    result['menu_settings'] = [dict(id=1, payload=json.dumps(settings, ensure_ascii=False))]
    return result


def current_snapshot(db):
    data = json.loads(rows(db, 'menu_settings', None)[0]['payload'])
    tags = {r['id']: r['name'] for r in rows(db, 'recipe_tags')}
    categories = {r['id']: r['name'] for r in rows(db, 'restaurant_categories')}
    data['recipeTags'] = [r['name'] for r in rows(db, 'recipe_tags') if r['listed']]
    data['restaurantCategories'] = [r['name'] for r in rows(db, 'restaurant_categories') if r['listed']]
    photos, links, companions, foods, items, visits, branches = (defaultdict(list) for _ in range(7))
    for row in rows(db, 'images', 'kind, restaurant_id, owner_id, item_position, position'):
        photos[(row['kind'], row['restaurant_id'], row['owner_id'], row['item_position'])].append(row['path'])
    def images(kind, restaurant='', owner='', item=-1):
        return photos[(kind, restaurant, owner, item)]
    data['legacyImagePaths'] = images('legacy')
    if data['recipeDraft'] is not None:
        data['recipeDraft']['imagePaths'] = images('draft')
    for r in rows(db, 'recipe_tag_links', 'recipe_id, position'):
        links[r['recipe_id']].append(tags[r['tag_id']])
    favorites = {(r['target_type'], r['target_id']) for r in rows(db, 'favorites', None)}
    data['recipes'] = [dict(id=r['id'], name=r['name'], note=r['note'], createdAt=r['created_at'],
        hiddenRounds=r['hidden_rounds'], tags=links[r['id']], imagePaths=images('recipe', owner=r['id']),
        favorite=('recipe', r['id']) in favorites) for r in rows(db, 'recipes')]
    def dish(row):
        return dict(name=row['name'], note=row['note'], price=row['price'], quantity=row['quantity'])
    for r in rows(db, 'visit_companions', 'restaurant_id, visit_id, position'):
        companions[(r['restaurant_id'], r['visit_id'])].append(r['name'])
    for r in rows(db, 'restaurant_dishes', 'restaurant_id, position'):
        foods[r['restaurant_id']].append(dict(id=r['id'], **dish(r),
            imagePaths=images('dish', r['restaurant_id'], r['id'])))
    for r in rows(db, 'restaurant_visit_items', 'restaurant_id, visit_id, position'):
        items[(r['restaurant_id'], r['visit_id'])].append(dict(dishId=r['dish_id'], **dish(r),
            imagePaths=images('item', r['restaurant_id'], r['visit_id'], r['position'])))
    for r in rows(db, 'restaurant_visits', 'restaurant_id, position'):
        visits[r['restaurant_id']].append(dict(id=r['id'], date=r['date'], totalCost=r['total_cost'],
            addressId=r['address_id'], address=r['address'], autoCost=bool(r['auto_cost']),
            note=r['note'], dishes=json.loads(r['dishes']), companions=companions[(r['restaurant_id'], r['id'])],
            items=items[(r['restaurant_id'], r['id'])], imagePaths=images('visit', r['restaurant_id'], r['id'])))
    for r in rows(db, 'restaurant_addresses', 'restaurant_id, position'):
        branches[r['restaurant_id']].append(dict(id=r['id'], province=r['province'], city=r['city'],
            county=r['county'], detail=r['detail'], location=None if r['latitude'] is None else
            dict(latitude=r['latitude'], longitude=r['longitude'])))
    data['restaurants'] = [dict(id=r['id'], name=r['name'], note=r['note'], link=r['link'],
        category='' if r['category_id'] is None else categories[r['category_id']],
        addresses=json.loads(r['addresses']), addressEntries=branches[r['id']], foods=foods[r['id']],
        records=visits[r['id']], favorite=('restaurant', r['id']) in favorites) for r in rows(db, 'restaurants')]
    for table, field in [('to_cook', 'toCook'), ('to_eat', 'toEat'), ('dislikes', 'dislikes')]:
        data[field] = [r['name'] for r in rows(db, table)]
    for kind, field in [('recipe', 'recipeSearchHistory'), ('restaurant', 'restaurantSearchHistory')]:
        data[field] = [r['keyword'] for r in rows(db, 'search_history', 'search_type, position') if r['search_type'] == kind]
    values = defaultdict(list)
    for r in rows(db, 'auto_tag_rule_values', 'mode, rule_key, position'):
        values[(r['mode'], r['rule_key'])].append(r['value'])
    for mode, field in [('literal', 'tagRules'), ('pattern', 'patternTagRules')]:
        data[field] = {r['rule_key']: values[(mode, r['rule_key'])]
            for r in rows(db, 'auto_tag_rules', 'mode, position') if r['mode'] == mode}
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='Backup of the previous 15-table database')
    parser.add_argument('output', type=Path, help='New database; source is never changed')
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output already exists; choose a new filename.')
    source = sqlite3.connect(args.source.resolve().as_uri() + '?mode=ro', uri=True)
    source.row_factory = sqlite3.Row
    snapshot = previous_snapshot(source)
    tables = create_rows(snapshot, source)
    schema = (Path(__file__).resolve().parents[1] / 'lib/core/menu_database_schema.dart').read_text()
    output = sqlite3.connect(args.output)
    output.row_factory = sqlite3.Row
    with output:
        for statement in re.findall("'''(.*?)'''", schema, re.S):
            output.execute(statement)
        for table, records in tables.items():
            if records:
                columns = list(records[0])
                output.executemany(f'INSERT INTO {table} ({",".join(columns)}) VALUES ({",".join("?" for _ in columns)})',
                                   [tuple(r[column] for column in columns) for r in records])
        if current_snapshot(output) != snapshot:
            raise RuntimeError('Business data differs after rewrite.')
        if output.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise RuntimeError('SQLite integrity check failed.')
        output.execute('PRAGMA user_version = 1')
    output.close()
    source.close()
    print(json.dumps({'output': str(args.output.resolve()), 'business_fields_unchanged': True,
                      'counts': {name: len(value) for name, value in tables.items()}}, ensure_ascii=False))


if __name__ == '__main__':
    main()
