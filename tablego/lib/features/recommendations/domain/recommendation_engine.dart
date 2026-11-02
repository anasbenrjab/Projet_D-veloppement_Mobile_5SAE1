import 'dart:math' as math;

import '../../favorites/data/models/restaurant_summary_model.dart';
import 'food_labels.dart';
import 'recommendation_models.dart';

/// Tunable weights of the recommender.  The defaults are the documented
/// values; tests and future tuning can pass other ones.
class RecommendationWeights {
  const RecommendationWeights({
    this.content = 0.45,
    this.collaborative = 0.40,
    this.popularity = 0.15,
    this.coldStartPopularity = 0.8,
    this.coldStartContent = 0.2,
    this.orderStrength = 1.0,
    this.favoriteDishStrength = 2.0,
    this.favoriteRestaurantStrength = 1.5,
    this.declaredDietStrength = 0.5,
    this.recencyHalfLifeDays = 30,
    this.alreadyKnownFactor = 0.8,
    this.cuisineFeature = 1.0,
    this.tagFeature = 0.6,
    this.restaurantFeature = 0.8,
    this.priceFeature = 0.3,
    this.maxRestaurants = 10,
    this.maxDishes = 10,
  });

  // Final score = content·C + collaborative·F + popularity·P (sum = 1).
  final double content;
  final double collaborative;
  final double popularity;

  // Cold start (client without any order or favorite).
  final double coldStartPopularity;
  final double coldStartContent;

  // How much one interaction counts in the taste vector and in the
  // collaborative matrix.
  final double orderStrength;
  final double favoriteDishStrength;
  final double favoriteRestaurantStrength;

  /// Weight of a declared diet (halal, végétarien…) in the taste vector.
  final double declaredDietStrength;

  /// An interaction this many days old counts half as much.
  final double recencyHalfLifeDays;

  /// Multiplier for items the client already ordered or favorited, so new
  /// suggestions can surface.
  final double alreadyKnownFactor;

  // Feature weights inside item vectors.
  final double cuisineFeature;
  final double tagFeature;
  final double restaurantFeature;
  final double priceFeature;

  final int maxRestaurants;
  final int maxDishes;
}

/// Hybrid recommender: hard filters, content-based scoring (cosine
/// similarity between a taste vector and item vectors), item-based
/// collaborative filtering, and popularity — fully local, deterministic,
/// and free of any database access so it can be unit-tested.
///
/// ## Steps
/// 1. **Hard filters** — a dish is kept only if it contains none of the
///    client's allergens (undeclared allergens count as unsafe for a client
///    with allergies) and satisfies every declared diet.  For a client with
///    a diet or allergy, a restaurant needs at least one such dish.
/// 2. **Content-based** — each item becomes a vector of features
///    (`cuisine:`, `tag:`, `resto:`, `prix:`).  The client's taste vector is
///    the sum of the vectors of what they ordered and favorited, weighted by
///    interaction type and recency (half-life [RecommendationWeights.
///    recencyHalfLifeDays]).  Score = cosine similarity, in [0, 1].
/// 3. **Collaborative filtering (item-based)** — from the orders and
///    favorites of all *other* clients, similarity between two items is the
///    cosine of their client-interaction vectors.  Score of an item = average
///    similarity to the client's own items, weighted by how much the client
///    likes each one.
/// 4. **Popularity** — interactions of other clients, relative to the most
///    popular compatible item.
/// 5. **Combination** — `0.45·content + 0.40·collaborative + 0.15·popularity`
///    (×0.8 for already known items).  Without any order or favorite (cold
///    start): `0.8·popularity + 0.2·content`, where content then only
///    reflects declared diets.
/// 6. **Explanation** — the strongest signal becomes a French sentence,
///    followed by the diet/allergen guarantee.
class RecommendationEngine {
  const RecommendationEngine({this.weights = const RecommendationWeights()});

  final RecommendationWeights weights;

  RecommendationResult recommend(
    RecommendationSnapshot snapshot, {
    required DateTime now,
  }) {
    return _Run(snapshot, weights, now).compute();
  }

  /// Cosine similarity of two sparse vectors; 0 when either is empty.
  static double cosine(Map<String, double> a, Map<String, double> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final (small, large) = a.length <= b.length ? (a, b) : (b, a);
    var dot = 0.0;
    small.forEach((k, v) {
      final other = large[k];
      if (other != null) dot += v * other;
    });
    if (dot == 0) return 0;
    return dot / (_norm(a) * _norm(b));
  }

  static double _norm(Map<String, double> v) =>
      math.sqrt(v.values.fold(0.0, (s, x) => s + x * x));
}

/// One computation, holding the intermediate state.
class _Run {
  _Run(this.s, this.w, this.now);

  final RecommendationSnapshot s;
  final RecommendationWeights w;
  final DateTime now;

  late final int userId = s.profile.userId;
  late final Set<String> diets =
      s.profile.diets.where(FoodLabels.knownDiets.contains).toSet();
  late final Set<String> allergens = s.profile.allergens;
  late final bool constrained = diets.isNotEmpty || allergens.isNotEmpty;

  late final Map<int, RestaurantSummaryModel> restaurantsById = {
    for (final r in s.restaurants) r.id: r,
  };
  late final Map<int, RecoDish> dishesById = {
    for (final d in s.dishes) d.id: d,
  };
  late final Map<int, List<RecoDish>> dishesByRestaurant = () {
    final map = <int, List<RecoDish>>{};
    for (final d in s.dishes) {
      map.putIfAbsent(d.restaurantId, () => []).add(d);
    }
    return map;
  }();

  // Collaborative data: user → item key ('d:<id>' / 'r:<id>') → value.
  final Map<int, Map<String, double>> _strengths = {};
  final Map<String, double> taste = {};
  late Map<String, double> _mine;
  late double _mineTotal;
  final Map<String, Map<int, double>> _itemUsers = {};
  final Map<String, double> _itemNorm = {};
  final Map<String, double> _popularity = {};
  final Map<String, double> _simCache = {};

  RecommendationResult compute() {
    // 1. Hard filters.
    final eligibleDishes = s.dishes
        .where((d) =>
            d.isAvailable &&
            restaurantsById.containsKey(d.restaurantId) &&
            _isAllowed(d))
        .toList();
    final compatibleCount = <int, int>{};
    for (final d in eligibleDishes) {
      compatibleCount[d.restaurantId] =
          (compatibleCount[d.restaurantId] ?? 0) + 1;
    }
    final eligibleRestaurants = s.restaurants
        .where((r) => !constrained || (compatibleCount[r.id] ?? 0) > 0)
        .toList();

    // 2–4. Taste vector, collaborative matrix, popularity.
    _buildInteractions();
    final coldStart = _mine.isEmpty;
    for (final diet in diets) {
      taste['tag:$diet'] = (taste['tag:$diet'] ?? 0) + w.declaredDietStrength;
    }

    // 5–6. Score, explain, rank.
    final maxRestaurantPop = _maxPopularity(
        eligibleRestaurants.map((r) => 'r:${r.id}'));
    final maxDishPop =
        _maxPopularity(eligibleDishes.map((d) => 'd:${d.id}'));

    final restaurants = [
      for (final r in eligibleRestaurants)
        _scoreRestaurant(r, compatibleCount[r.id] ?? 0, maxRestaurantPop,
            coldStart),
    ]..sort((a, b) => _compare(
        a.score, b.score, a.restaurant.name, b.restaurant.name));

    final dishes = [
      for (final d in eligibleDishes) _scoreDish(d, maxDishPop, coldStart),
    ]..sort((a, b) => _compare(a.score, b.score, a.dish.name, b.dish.name));

    return RecommendationResult(
      restaurants: restaurants.take(w.maxRestaurants).toList(),
      dishes: dishes.take(w.maxDishes).toList(),
      coldStart: coldStart,
    );
  }

  static int _compare(double sa, double sb, String na, String nb) {
    final byScore = sb.compareTo(sa);
    return byScore != 0 ? byScore : na.compareTo(nb);
  }

  // ── 1. Hard filters ───────────────────────────────────────────────────────

  bool _isAllowed(RecoDish d) {
    if (allergens.isNotEmpty) {
      final declared = d.allergens;
      // Unknown allergens are unsafe for a client with allergies.
      if (declared == null) return false;
      if (declared.any(allergens.contains)) return false;
    }
    return diets.every((diet) => FoodLabels.satisfiesDiet(diet, d.tags, d.allergens));
  }

  // ── 2. Features ───────────────────────────────────────────────────────────

  final Map<int, Map<String, double>> _dishFeatures = {};
  final Map<int, Map<String, double>> _restaurantFeatures = {};

  String? _cuisineKey(int restaurantId) {
    final cuisine = restaurantsById[restaurantId]?.cuisineType ?? '';
    final key = FoodLabels.normalize(cuisine);
    return key.isEmpty ? null : key;
  }

  static String _priceBand(double price) =>
      price < 8 ? 'petit' : (price < 15 ? 'moyen' : 'eleve');

  Map<String, double> _featuresOfDish(RecoDish d) =>
      _dishFeatures.putIfAbsent(d.id, () {
        final f = <String, double>{};
        final cuisine = _cuisineKey(d.restaurantId);
        if (cuisine != null) f['cuisine:$cuisine'] = w.cuisineFeature;
        for (final t in d.tags) {
          f['tag:$t'] = w.tagFeature;
        }
        f['resto:${d.restaurantId}'] = w.restaurantFeature;
        f['prix:${_priceBand(d.price)}'] = w.priceFeature;
        return f;
      });

  Map<String, double> _featuresOfRestaurant(int restaurantId) =>
      _restaurantFeatures.putIfAbsent(restaurantId, () {
        final f = <String, double>{};
        final cuisine = _cuisineKey(restaurantId);
        if (cuisine != null) f['cuisine:$cuisine'] = w.cuisineFeature;
        f['resto:$restaurantId'] = w.restaurantFeature;
        final menu = (dishesByRestaurant[restaurantId] ?? const <RecoDish>[])
            .where((d) => d.isAvailable)
            .toList();
        if (menu.isNotEmpty) {
          final tagCounts = <String, int>{};
          for (final d in menu) {
            for (final t in d.tags) {
              tagCounts[t] = (tagCounts[t] ?? 0) + 1;
            }
          }
          tagCounts.forEach((t, n) => f['tag:$t'] = w.tagFeature * n / menu.length);
          final mean =
              menu.fold(0.0, (sum, d) => sum + d.price) / menu.length;
          f['prix:${_priceBand(mean)}'] = w.priceFeature;
        }
        return f;
      });

  // ── 3–4. Interactions: taste, collaborative matrix, popularity ────────────

  double _strengthOf(InteractionKind kind) => switch (kind) {
        InteractionKind.order => w.orderStrength,
        InteractionKind.favoriteDish => w.favoriteDishStrength,
        InteractionKind.favoriteRestaurant => w.favoriteRestaurantStrength,
      };

  double _recency(DateTime? at) {
    if (at == null) return 1;
    final days = now.difference(at).inMinutes / (60 * 24);
    if (days <= 0) return 1;
    return math.pow(0.5, days / w.recencyHalfLifeDays).toDouble();
  }

  void _buildInteractions() {
    void add(int user, String key, double value) {
      final items = _strengths.putIfAbsent(user, () => {});
      items[key] = (items[key] ?? 0) + value;
    }

    for (final i in s.interactions) {
      final weight = _strengthOf(i.kind) * _recency(i.at);
      final dish = i.dishId == null ? null : dishesById[i.dishId];
      final restaurantId = i.restaurantId ?? dish?.restaurantId;

      if (dish != null) {
        add(i.userId, 'd:${dish.id}', weight);
        add(i.userId, 'r:${dish.restaurantId}', weight * 0.5);
      } else if (restaurantId != null) {
        add(i.userId, 'r:$restaurantId', weight);
      }

      if (i.userId != userId) continue;
      final features = dish != null
          ? _featuresOfDish(dish)
          : (restaurantId != null && restaurantsById.containsKey(restaurantId)
              ? _featuresOfRestaurant(restaurantId)
              : null);
      features?.forEach((k, v) => taste[k] = (taste[k] ?? 0) + v * weight);
    }

    // Diminishing returns for repeated interactions: v = ln(1 + raw).
    _strengths.updateAll((_, items) =>
        items.map((k, raw) => MapEntry(k, math.log(1 + raw))));

    _mine = _strengths[userId] ?? const {};
    _mineTotal = _mine.values.fold(0.0, (s, v) => s + v);

    // Item → other clients' values (the target is excluded so "clients who
    // like X also like Y" only reflects other people).
    _strengths.forEach((user, items) {
      if (user == userId) return;
      items.forEach((key, v) {
        _itemUsers.putIfAbsent(key, () => {})[user] = v;
        _popularity[key] = (_popularity[key] ?? 0) + v;
      });
    });
    _itemUsers.forEach((key, users) {
      _itemNorm[key] =
          math.sqrt(users.values.fold(0.0, (s, v) => s + v * v));
    });
  }

  /// Item-item cosine similarity over other clients' interactions.
  double _similarity(String a, String b) {
    final cacheKey = a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';
    return _simCache.putIfAbsent(cacheKey, () {
      final ua = _itemUsers[a];
      final ub = _itemUsers[b];
      if (ua == null || ub == null) return 0;
      var dot = 0.0;
      ua.forEach((user, v) {
        final other = ub[user];
        if (other != null) dot += v * other;
      });
      if (dot == 0) return 0;
      return dot / (_itemNorm[a]! * _itemNorm[b]!);
    });
  }

  /// Collaborative score of [key] and the client item that contributed most.
  (double, String?) _collaborative(String key) {
    if (_mineTotal == 0) return (0, null);
    var sum = 0.0;
    var best = 0.0;
    String? via;
    _mine.forEach((item, value) {
      if (item == key) return;
      final contribution = value * _similarity(item, key);
      if (contribution <= 0) return;
      sum += contribution;
      if (contribution > best) {
        best = contribution;
        via = item;
      }
    });
    return (sum / _mineTotal, via);
  }

  double _maxPopularity(Iterable<String> keys) =>
      keys.fold(0.0, (m, k) => math.max(m, _popularity[k] ?? 0));

  // ── 5. Scoring ────────────────────────────────────────────────────────────

  RestaurantRecommendation _scoreRestaurant(RestaurantSummaryModel r,
      int compatibleDishes, double maxPop, bool coldStart) {
    final key = 'r:${r.id}';
    final scored = _score(key, _featuresOfRestaurant(r.id), maxPop, coldStart);
    final reasons = <String>[
      _primaryReason(scored, _featuresOfRestaurant(r.id), coldStart,
          isDish: false),
      ?_restaurantSafety(compatibleDishes),
    ];
    return RestaurantRecommendation(
      restaurant: r,
      score: scored.score,
      breakdown: scored.breakdown,
      reasons: reasons,
      compatibleDishCount: compatibleDishes,
    );
  }

  DishRecommendation _scoreDish(RecoDish d, double maxPop, bool coldStart) {
    final key = 'd:${d.id}';
    final scored = _score(key, _featuresOfDish(d), maxPop, coldStart);
    final reasons = <String>[
      _primaryReason(scored, _featuresOfDish(d), coldStart, isDish: true),
      ?_dishSafety(),
    ];
    return DishRecommendation(
      dish: d,
      restaurantName: restaurantsById[d.restaurantId]?.name ?? '',
      score: scored.score,
      breakdown: scored.breakdown,
      reasons: reasons,
    );
  }

  _Scored _score(String key, Map<String, double> features, double maxPop,
      bool coldStart) {
    final content = RecommendationEngine.cosine(taste, features);
    final (collaborative, via) = _collaborative(key);
    final popularity = maxPop > 0 ? (_popularity[key] ?? 0) / maxPop : 0.0;

    double score;
    if (coldStart) {
      score = w.coldStartPopularity * popularity + w.coldStartContent * content;
    } else {
      score = w.content * content +
          w.collaborative * collaborative +
          w.popularity * popularity;
      if (_mine.containsKey(key)) score *= w.alreadyKnownFactor;
    }
    return _Scored(
      score: score,
      breakdown: ScoreBreakdown(
        content: content,
        collaborative: collaborative,
        popularity: popularity,
      ),
      via: via,
    );
  }

  // ── 6. Explanations ───────────────────────────────────────────────────────

  String _primaryReason(_Scored scored, Map<String, double> features,
      bool coldStart, {required bool isDish}) {
    final b = scored.breakdown;
    final candidates = <(double, String? Function())>[
      (
        (coldStart ? w.coldStartContent : w.content) * b.content,
        () => _contentReason(features, isDish: isDish),
      ),
      (
        coldStart ? 0 : w.collaborative * b.collaborative,
        () => scored.via == null
            ? null
            : 'Apprécié des clients qui aiment ${_nameOf(scored.via!)}',
      ),
      (
        (coldStart ? w.coldStartPopularity : w.popularity) * b.popularity,
        () => 'Populaire chez les clients TableGo',
      ),
    ]..sort((x, y) => y.$1.compareTo(x.$1));

    for (final (contribution, build) in candidates) {
      if (contribution <= 1e-6) break;
      final reason = build();
      if (reason != null) return reason;
    }
    return 'À découvrir';
  }

  /// Sentence for the feature the client's taste and the item share most.
  String? _contentReason(Map<String, double> features, {required bool isDish}) {
    String? bestKey;
    var best = 0.0;
    features.forEach((k, v) {
      // Declared diets are a filter, already stated in the safety reason.
      if (k.startsWith('tag:') && diets.contains(k.substring(4))) return;
      final t = taste[k];
      if (t == null) return;
      final shared = t * v;
      if (shared > best) {
        best = shared;
        bestKey = k;
      }
    });
    final key = bestKey;
    if (key == null) return null;
    final value = key.substring(key.indexOf(':') + 1);
    if (key.startsWith('cuisine:')) {
      return 'Parce que vous aimez la cuisine ${FoodLabels.cuisineDisplay(value)}';
    }
    if (key.startsWith('tag:')) {
      return 'Parce que vous aimez les plats ${FoodLabels.display(value)}';
    }
    if (key.startsWith('resto:')) {
      final name = restaurantsById[int.parse(value)]?.name ?? '';
      return isDish
          ? 'De $name, un restaurant que vous appréciez'
          : 'Un restaurant que vous appréciez déjà';
    }
    return 'Dans vos prix habituels';
  }

  String _nameOf(String itemKey) {
    final id = int.parse(itemKey.substring(2));
    return itemKey.startsWith('d:')
        ? (dishesById[id]?.name ?? '')
        : (restaurantsById[id]?.name ?? '');
  }

  List<String> get _dietLabels =>
      (diets.toList()..sort()).map(FoodLabels.display).toList();

  List<String> get _allergenLabels =>
      (allergens.toList()..sort()).map(FoodLabels.display).toList();

  String? _dishSafety() {
    final parts = <String>[];
    if (diets.isNotEmpty) parts.add('Compatible ${FoodLabels.joinFr(_dietLabels)}');
    if (allergens.isNotEmpty) {
      parts.add('${parts.isEmpty ? 'Sans' : 'sans'} '
          '${FoodLabels.joinFr(_allergenLabels)}');
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  String? _restaurantSafety(int compatibleDishes) {
    if (!constrained) return null;
    final plural = compatibleDishes > 1;
    final parts = <String>[
      '$compatibleDishes plat${plural ? 's' : ''}',
      if (diets.isNotEmpty)
        'compatible${plural ? 's' : ''} ${FoodLabels.joinFr(_dietLabels)}',
    ];
    var text = parts.join(' ');
    if (allergens.isNotEmpty) {
      text += '${diets.isNotEmpty ? ',' : ''} sans '
          '${FoodLabels.joinFr(_allergenLabels)}';
    }
    return text;
  }
}

class _Scored {
  const _Scored({required this.score, required this.breakdown, this.via});

  final double score;
  final ScoreBreakdown breakdown;
  final String? via;
}
