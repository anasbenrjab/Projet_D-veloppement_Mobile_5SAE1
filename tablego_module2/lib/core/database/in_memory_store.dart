import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'seed_images.dart';

/// Pure Dart in-memory database that mimics the SQLite CRUD interface.
/// Used on web (sqflite has no native engine in the browser).
/// Tables are persisted as JSON in localStorage so data survives a reload.
class InMemoryStore {
  InMemoryStore._() {
    _seed();
    debugPrint('[InMemoryStore] ✓ seeded');
  }

  static final InMemoryStore instance = InMemoryStore._();
  static const _prefsKey = 'tablego_module2_db';

  // Each table is a list of rows (Map<String,dynamic>)
  final _tables = <String, List<Map<String, dynamic>>>{
    'dishes': [],
    'cart_items': [],
    'orders': [],
    'order_items': [],
  };

  // Auto-increment counters per table
  final _counters = <String, int>{
    'dishes': 0,
    'cart_items': 0,
    'orders': 0,
    'order_items': 0,
  };

  bool _initialized = false;

  /// Restores tables from localStorage (if any were saved before).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        await _persist();
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final tables = data['tables'] as Map<String, dynamic>;
      final counters = data['counters'] as Map<String, dynamic>;
      tables.forEach((name, rows) {
        _tables[name] = (rows as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
      });
      counters.forEach((name, v) => _counters[name] = v as int);
      debugPrint('[InMemoryStore] ✓ restored from localStorage');
    } catch (e) {
      debugPrint('[InMemoryStore] restore failed: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode({'tables': _tables, 'counters': _counters}));
    } catch (e) {
      debugPrint('[InMemoryStore] persist failed: $e');
    }
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> row) async {
    _counters[table] = (_counters[table] ?? 0) + 1;
    final id = _counters[table]!;
    final newRow = Map<String, dynamic>.from(row)..['id'] = id;
    _tables.putIfAbsent(table, () => []).add(newRow);
    await _persist();
    return id;
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    var rows = List<Map<String, dynamic>>.from(
      _tables[table]!.map((r) => Map<String, dynamic>.from(r)),
    );

    if (where != null && whereArgs != null) {
      rows = _applyWhere(rows, where, whereArgs);
    }

    if (orderBy != null) {
      rows = _applyOrderBy(rows, orderBy);
    }

    return rows;
  }

  Future<int> update(
    String table,
    Map<String, dynamic> row, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final tableRows = _tables[table]!;
    int count = 0;
    for (int i = 0; i < tableRows.length; i++) {
      if (_matchesWhere(tableRows[i], where, whereArgs)) {
        tableRows[i] = {...tableRows[i], ...row};
        count++;
      }
    }
    if (count > 0) await _persist();
    return count;
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final tableRows = _tables[table]!;
    final before = tableRows.length;
    tableRows.removeWhere((r) => _matchesWhere(r, where, whereArgs));
    final removed = before - tableRows.length;
    if (removed > 0) await _persist();
    return removed;
  }

  Future<List<Map<String, dynamic>>> rawQuery(
      String sql, List<dynamic> args) async {
    // Support the specific JOIN query used by CartRepository
    if (sql.contains('FROM cart_items ci') && sql.contains('JOIN dishes d')) {
      return _cartJoinQuery();
    }
    // Support SUM query for cart count
    if (sql.contains('SUM(quantity)') && sql.contains('cart_items')) {
      final total = _tables['cart_items']!
          .fold<int>(0, (sum, r) => sum + (r['quantity'] as int? ?? 0));
      return [
        {'total': total}
      ];
    }
    // Support dish search query
    if (sql.contains('LOWER(name) LIKE') && args.length >= 4) {
      final restaurantId = args[0];
      final pattern = (args[1] as String)
          .replaceAll('%', '')
          .toLowerCase();
      return _tables['dishes']!
          .where((r) =>
              r['restaurant_id'] == restaurantId &&
              r['is_available'] == 1 &&
              ((r['name'] as String).toLowerCase().contains(pattern) ||
                  (r['description'] as String).toLowerCase().contains(pattern) ||
                  (r['category'] as String).toLowerCase().contains(pattern)))
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }
    return [];
  }

  // ── Where clause parser ────────────────────────────────────────────────────

  List<Map<String, dynamic>> _applyWhere(
    List<Map<String, dynamic>> rows,
    String where,
    List<dynamic> args,
  ) {
    return rows.where((r) => _matchesWhere(r, where, args)).toList();
  }

  bool _matchesWhere(
      Map<String, dynamic> row, String where, List<dynamic> args) {
    // Parse simple conditions separated by AND
    // Supports: col = ?, col = 1, "1" (always true)
    if (where.trim() == '1') return true;

    final conditions = where.split(RegExp(r'\s+AND\s+', caseSensitive: false));
    int argIdx = 0;

    for (final cond in conditions) {
      final trimmed = cond.trim();

      // col = ?
      final eqMatch = RegExp(r'^(\w+)\s*=\s*\?$').firstMatch(trimmed);
      if (eqMatch != null) {
        final col = eqMatch.group(1)!;
        final val = args[argIdx++];
        if (row[col] != val && row[col].toString() != val.toString()) {
          return false;
        }
        continue;
      }

      // col = literal (e.g. is_available = 1)
      final litMatch =
          RegExp(r'^(\w+)\s*=\s*(\d+)$').firstMatch(trimmed);
      if (litMatch != null) {
        final col = litMatch.group(1)!;
        final val = int.parse(litMatch.group(2)!);
        if (row[col] != val) return false;
        continue;
      }
    }

    return true;
  }

  // ── Order by ────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _applyOrderBy(
      List<Map<String, dynamic>> rows, String orderBy) {
    final parts = orderBy.split(',');
    final result = List<Map<String, dynamic>>.from(rows);

    result.sort((a, b) {
      for (final part in parts) {
        final tokens = part.trim().split(RegExp(r'\s+'));
        final col = tokens[0];
        final desc =
            tokens.length > 1 && tokens[1].toUpperCase() == 'DESC';

        final va = a[col];
        final vb = b[col];

        int cmp = 0;
        if (va is String && vb is String) {
          cmp = va.compareTo(vb);
        } else if (va is num && vb is num) {
          cmp = va.compareTo(vb);
        }

        if (cmp != 0) return desc ? -cmp : cmp;
      }
      return 0;
    });

    return result;
  }

  // ── JOIN query for cart ────────────────────────────────────────────────────

  List<Map<String, dynamic>> _cartJoinQuery() {
    final cartItems = _tables['cart_items']!;
    final dishes = _tables['dishes']!;
    final result = <Map<String, dynamic>>[];

    for (final ci in cartItems) {
      final dishId = ci['dish_id'];
      final dish = dishes.where((d) => d['id'] == dishId).firstOrNull;
      if (dish == null) continue;

      result.add({
        'id': ci['id'],
        'dish_id': ci['dish_id'],
        'quantity': ci['quantity'],
        'added_at': ci['added_at'],
        'name': dish['name'],
        'description': dish['description'],
        'price': dish['price'],
        'category': dish['category'],
        'image_path': dish['image_path'],
        'is_available': dish['is_available'],
        'allergens': dish['allergens'],
        'restaurant_id': dish['restaurant_id'],
        'dish_created_at': dish['created_at'],
      });
    }

    return result;
  }

  // ── Seed data ───────────────────────────────────────────────────────────────

  void _seed() {
    final now = DateTime.now().toIso8601String();
    final dishes = <Map<String, dynamic>>[
      {
        'name': 'Couscous Royal',
        'description':
            'Semoule fine avec légumes mijotés, merguez, poulet et agneau.',
        'price': 28.500,
        'category': 'Plat principal',
        'image_path': null,
        'is_available': 1,
        'allergens': 'Gluten, Lait',
        'restaurant_id': 1,
        'created_at': now,
      },
      {
        'name': 'Salade Méchouia',
        'description':
            'Poivrons et tomates grillés, thon, câpres et œufs durs.',
        'price': 12.000,
        'category': 'Entrée',
        'image_path': null,
        'is_available': 1,
        'allergens': 'Poisson, Œuf',
        'restaurant_id': 1,
        'created_at': now,
      },
      {
        'name': 'Tajine Agneau',
        'description': 'Agneau tendre aux épices, citrons confits et olives.',
        'price': 32.000,
        'category': 'Plat principal',
        'image_path': null,
        'is_available': 1,
        'allergens': 'Aucun',
        'restaurant_id': 1,
        'created_at': now,
      },
      {
        'name': 'Brik au Thon',
        'description': 'Feuille de brick croustillante, thon, câpres et œuf.',
        'price': 7.500,
        'category': 'Entrée',
        'image_path': null,
        'is_available': 1,
        'allergens': 'Gluten, Poisson, Œuf',
        'restaurant_id': 1,
        'created_at': now,
      },
      {
        'name': 'Lablabi',
        'description': 'Soupe de pois chiches au cumin, harissa et croûtons.',
        'price': 9.000,
        'category': 'Entrée',
        'image_path': null,
        'is_available': 1,
        'allergens': 'Gluten',
        'restaurant_id': 1,
        'created_at': now,
      },
      {
        'name': 'Makroudh',
        'description': 'Gâteau de semoule aux dattes, frit et trempé au miel.',
        'price': 5.000,
        'category': 'Dessert',
        'image_path': null,
        'is_available': 1,
        'allergens': 'Gluten, Fruits à coque',
        'restaurant_id': 1,
        'created_at': now,
      },
      {
        'name': 'Thé à la Menthe',
        'description': 'Thé vert parfumé à la menthe fraîche et pignons.',
        'price': 4.000,
        'category': 'Boisson',
        'image_path': null,
        'is_available': 1,
        'allergens': 'Fruits à coque',
        'restaurant_id': 1,
        'created_at': now,
      },
      {
        'name': 'Crème Caramel',
        'description': 'Crème onctueuse renversée au caramel doré.',
        'price': 8.000,
        'category': 'Dessert',
        'image_path': null,
        'is_available': 1,
        'allergens': 'Lait, Œuf',
        'restaurant_id': 1,
        'created_at': now,
      },
    ];
    for (final d in dishes) {
      // Manually assign IDs for seed data
      _counters['dishes'] = (_counters['dishes'] ?? 0) + 1;
      _tables['dishes']!
          .add(Map<String, dynamic>.from(d)
            ..['id'] = _counters['dishes']!
            ..['image_path'] = kSeedDishImages[d['name']]);
    }
  }
}
