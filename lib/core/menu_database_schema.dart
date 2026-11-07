part of 'menu_database.dart';

const _schema = [
  _couponSchema,
  '''CREATE TABLE recipes (id TEXT PRIMARY KEY, position INTEGER NOT NULL,
 name TEXT NOT NULL, note TEXT NOT NULL, hidden_rounds INTEGER NOT NULL, created_at TEXT NOT NULL)''',
  '''CREATE TABLE restaurants (id TEXT PRIMARY KEY, position INTEGER NOT NULL,
 name TEXT NOT NULL, category_id TEXT, note TEXT NOT NULL, link TEXT NOT NULL, addresses TEXT NOT NULL)''',
  '''CREATE TABLE restaurant_addresses (
          restaurant_id TEXT NOT NULL, id TEXT NOT NULL,
          position INTEGER NOT NULL, province TEXT NOT NULL,
          city TEXT NOT NULL, county TEXT NOT NULL, detail TEXT NOT NULL,
          latitude REAL, longitude REAL,
          PRIMARY KEY (restaurant_id, id),
          CHECK ((latitude IS NULL AND longitude IS NULL) OR
                 (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180
                  AND latitude IS NOT NULL AND longitude IS NOT NULL))
        )''',
  '''CREATE TABLE menu_settings (
          id INTEGER PRIMARY KEY CHECK (id = 1), payload TEXT NOT NULL
        )''',
  '''CREATE TABLE favorites (
          target_type TEXT NOT NULL CHECK (target_type IN ('recipe', 'restaurant')),
          target_id TEXT NOT NULL, PRIMARY KEY (target_type, target_id)
        )''',
  '''CREATE TABLE to_cook (
          position INTEGER PRIMARY KEY, name TEXT NOT NULL
        )''',
  '''CREATE TABLE to_eat (
          position INTEGER PRIMARY KEY, name TEXT NOT NULL
        )''',
  '''CREATE TABLE dislikes (
          position INTEGER PRIMARY KEY, name TEXT NOT NULL
        )''',
  '''CREATE TABLE auto_tag_rules (
          mode TEXT NOT NULL CHECK (mode IN ('literal', 'pattern')),
          rule_key TEXT NOT NULL, position INTEGER NOT NULL,
          PRIMARY KEY (mode, rule_key)
        )''',
  '''CREATE TABLE auto_tag_rule_values (
          mode TEXT NOT NULL, rule_key TEXT NOT NULL,
          position INTEGER NOT NULL, value TEXT NOT NULL,
          PRIMARY KEY (mode, rule_key, position)
        )''',
  '''CREATE TABLE recipe_tags (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE,
 position INTEGER NOT NULL, listed INTEGER NOT NULL CHECK (listed IN (0,1)))''',
  '''CREATE TABLE recipe_tag_links (recipe_id TEXT NOT NULL, position INTEGER NOT NULL,
 tag_id TEXT NOT NULL, PRIMARY KEY (recipe_id,position))''',
  '''CREATE TABLE restaurant_dishes (restaurant_id TEXT NOT NULL, id TEXT NOT NULL,
 position INTEGER NOT NULL, name TEXT NOT NULL, price REAL NOT NULL, quantity INTEGER NOT NULL,
 note TEXT NOT NULL, PRIMARY KEY (restaurant_id,id))''',
  '''CREATE TABLE restaurant_visits (restaurant_id TEXT NOT NULL, id TEXT NOT NULL,
 position INTEGER NOT NULL, date TEXT NOT NULL, total_cost REAL NOT NULL, address_id TEXT NOT NULL,
 address TEXT NOT NULL, auto_cost INTEGER NOT NULL CHECK (auto_cost IN (0,1)),
 note TEXT NOT NULL, dishes TEXT NOT NULL, PRIMARY KEY (restaurant_id,id))''',
  '''CREATE TABLE restaurant_visit_items (restaurant_id TEXT NOT NULL,
 visit_id TEXT NOT NULL, position INTEGER NOT NULL, dish_id TEXT NOT NULL, name TEXT NOT NULL,
 price REAL NOT NULL, quantity INTEGER NOT NULL, note TEXT NOT NULL,
 PRIMARY KEY (restaurant_id,visit_id,position))''',
  '''CREATE TABLE restaurant_categories (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE,
 position INTEGER NOT NULL, listed INTEGER NOT NULL CHECK (listed IN (0,1)))''',
  '''CREATE TABLE visit_companions (restaurant_id TEXT NOT NULL, visit_id TEXT NOT NULL,
 position INTEGER NOT NULL, name TEXT NOT NULL, PRIMARY KEY (restaurant_id,visit_id,position))''',
  '''CREATE TABLE search_history (search_type TEXT NOT NULL CHECK (search_type IN ('recipe','restaurant')),
 position INTEGER NOT NULL, keyword TEXT NOT NULL, PRIMARY KEY (search_type,position))''',
  '''CREATE TABLE images (kind TEXT NOT NULL CHECK (kind IN ('recipe','dish','visit','item','draft','legacy')),
 restaurant_id TEXT NOT NULL, owner_id TEXT NOT NULL, item_position INTEGER NOT NULL,
 position INTEGER NOT NULL, path TEXT NOT NULL,
 PRIMARY KEY (kind,restaurant_id,owner_id,item_position,position))''',
  '''CREATE INDEX images_restaurant ON images (restaurant_id)''',
  '''CREATE INDEX images_owner ON images (kind,owner_id)''',
  '''CREATE INDEX recipe_tag_links_tag ON recipe_tag_links (tag_id)''',
  '''CREATE INDEX restaurants_category ON restaurants (category_id)''',
  '''CREATE INDEX restaurant_visits_date ON restaurant_visits (date)''',
  '''CREATE INDEX visit_companions_name ON visit_companions (name)''',
];
