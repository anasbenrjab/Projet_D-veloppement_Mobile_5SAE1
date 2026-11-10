/// DDL for Module 2 (Menu + Commande).
///
/// * `dishes` is the shared table from `shared_tables.dart`; Module 2 only
///   extends it (`category`).  Dish photos use the existing `photo_path`
///   column and allergens the existing JSON `allergens` column.
/// * `cart_items`, `orders`, `order_items` are Module 2's own tables.  Orders
///   are the single source of truth for what a client ordered.
/// * `order_history` (read by the recommender) becomes a **VIEW** over
///   `orders` + `order_items`, so the data is never stored twice and the
///   recommender keeps reading the same four columns.
///
/// Every step is idempotent: [create] runs from `onCreate` (new databases)
/// and from the v4 block of `DatabaseHelper.migrate` (existing databases).
library;

import 'package:sqflite/sqflite.dart';

class MenuTables {
  MenuTables._();

  static Future<void> create(DatabaseExecutor db) async {
    await addDishCategory(db);
    await createCartAndOrders(db);
    await replaceOrderHistoryWithView(db);
  }

  /// `dishes.category` — one of `DishModel.categories` ("Entrée",
  /// "Plat principal", …).  `NULL` on dishes created before v4; the model
  /// reads it as "Plat principal".
  static Future<void> addDishCategory(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(dishes)');
    if (!columns.any((c) => c['name'] == 'category')) {
      await db.execute('ALTER TABLE dishes ADD COLUMN category TEXT NULL');
    }
  }

  static Future<void> createCartAndOrders(DatabaseExecutor db) async {
    // ── cart_items ─────────────────────────────────────────────────────────
    // One cart per client; a dish appears at most once (quantity grows).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id   INTEGER NOT NULL,
        dish_id   INTEGER NOT NULL,
        quantity  INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
        added_at  TEXT    NOT NULL
                    DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        UNIQUE (user_id, dish_id),
        FOREIGN KEY (user_id) REFERENCES users(id)  ON DELETE CASCADE,
        FOREIGN KEY (dish_id) REFERENCES dishes(id) ON DELETE CASCADE
      )
    ''');

    // ── orders ─────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       INTEGER NOT NULL,
        restaurant_id INTEGER NOT NULL,
        order_type    TEXT    NOT NULL,
        status        TEXT    NOT NULL DEFAULT 'reçue',
        total_price   REAL    NOT NULL DEFAULT 0,
        note          TEXT    NOT NULL DEFAULT '',
        client_name   TEXT    NOT NULL DEFAULT 'Client',
        created_at    TEXT    NOT NULL
                        DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
        FOREIGN KEY (user_id)
          REFERENCES users(id)               ON DELETE CASCADE,
        FOREIGN KEY (restaurant_id)
          REFERENCES restaurant_profiles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_restaurant_id '
      'ON orders(restaurant_id)',
    );

    // ── order_items ────────────────────────────────────────────────────────
    // dish_name / dish_price are a snapshot taken at checkout, so the order
    // stays readable after the dish is edited or deleted (dish_id → NULL).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id    INTEGER NOT NULL,
        dish_id     INTEGER NULL,
        dish_name   TEXT    NOT NULL,
        dish_price  REAL    NOT NULL,
        quantity    INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (dish_id)  REFERENCES dishes(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_order_id '
      'ON order_items(order_id)',
    );
  }

  /// Replaces the v1–v3 `order_history` **table** with a **view** built from
  /// `orders` + `order_items` (one row per order line).
  ///
  /// Existing rows are first copied into `orders`/`order_items` — one order
  /// per row, status "prête" — so no history is lost.  Does nothing when
  /// `order_history` is already a view.
  static Future<void> replaceOrderHistoryWithView(DatabaseExecutor db) async {
    final existing = await db.rawQuery(
      "SELECT type FROM sqlite_master WHERE name = 'order_history'",
    );
    final type = existing.isEmpty ? null : existing.first['type'];
    if (type == 'view') return;

    if (type == 'table') {
      final rows = await db.rawQuery('''
        SELECT oh.user_id, oh.restaurant_id, oh.dish_id, oh.ordered_at,
               d.name AS dish_name, d.price AS dish_price
          FROM order_history oh
          LEFT JOIN dishes d ON d.id = oh.dish_id
         ORDER BY oh.id
      ''');
      for (final r in rows) {
        final price = (r['dish_price'] as num?)?.toDouble() ?? 0.0;
        final orderId = await db.insert('orders', {
          'user_id': r['user_id'],
          'restaurant_id': r['restaurant_id'],
          'order_type': 'sur place',
          'status': 'prête',
          'total_price': price,
          'created_at': r['ordered_at'],
        });
        await db.insert('order_items', {
          'order_id': orderId,
          'dish_id': r['dish_id'],
          'dish_name': r['dish_name'] ?? 'Plat supprimé',
          'dish_price': price,
          'quantity': 1,
        });
      }
      await db.execute('DROP TABLE order_history');
    }

    await db.execute('''
      CREATE VIEW IF NOT EXISTS order_history AS
        SELECT oi.id         AS id,
               o.user_id     AS user_id,
               o.restaurant_id AS restaurant_id,
               oi.dish_id    AS dish_id,
               o.created_at  AS ordered_at
          FROM order_items oi
          JOIN orders o ON o.id = oi.order_id
    ''');
  }
}
