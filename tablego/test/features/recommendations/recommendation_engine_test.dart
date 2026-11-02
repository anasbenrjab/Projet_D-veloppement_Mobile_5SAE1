import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/features/favorites/data/models/restaurant_summary_model.dart';
import 'package:tablego/features/recommendations/domain/recommendation_engine.dart';
import 'package:tablego/features/recommendations/domain/recommendation_models.dart';

// ── Fixture helpers ───────────────────────────────────────────────────────────

const _me = 1;
final _now = DateTime.utc(2026, 11, 2, 12);
const _engine = RecommendationEngine();

RestaurantSummaryModel _resto(int id, String name, [String cuisine = '']) =>
    RestaurantSummaryModel(
        id: id, name: name, address: '', cuisineType: cuisine, favoritedAt: '');

RecoDish _dish(
  int id,
  int restaurantId,
  String name, {
  Set<String> tags = const {},
  Set<String>? allergens = const {},
  double price = 12,
}) =>
    RecoDish(
      id: id,
      restaurantId: restaurantId,
      name: name,
      price: price,
      tags: tags,
      allergens: allergens,
    );

RecoInteraction _order(int user, int dishId, {int daysAgo = 0}) =>
    RecoInteraction(
      userId: user,
      kind: InteractionKind.order,
      dishId: dishId,
      at: _now.subtract(Duration(days: daysAgo)),
    );

RecoInteraction _favResto(int user, int restaurantId) => RecoInteraction(
    userId: user,
    kind: InteractionKind.favoriteRestaurant,
    restaurantId: restaurantId,
    at: _now);

RecommendationResult _run({
  Set<String> diets = const {},
  Set<String> allergens = const {},
  required List<RestaurantSummaryModel> restaurants,
  required List<RecoDish> dishes,
  List<RecoInteraction> interactions = const [],
}) =>
    _engine.recommend(
      RecommendationSnapshot(
        profile: RecoClientProfile(
            userId: _me, diets: diets, allergens: allergens),
        restaurants: restaurants,
        dishes: dishes,
        interactions: interactions,
      ),
      now: _now,
    );

List<String> _dishNames(RecommendationResult r) =>
    r.dishes.map((d) => d.dish.name).toList();

List<String> _restaurantNames(RecommendationResult r) =>
    r.restaurants.map((x) => x.restaurant.name).toList();

void main() {
  // ── 1. Hard filters ─────────────────────────────────────────────────────────
  group('hard filters', () {
    test('never recommends a dish containing one of the client allergens', () {
      final r = _run(
        allergens: {'arachides'},
        restaurants: [_resto(1, 'R')],
        dishes: [
          _dish(1, 1, 'Cookie', allergens: {'gluten', 'arachides'}),
          _dish(2, 1, 'Salade', allergens: {}),
        ],
      );
      expect(_dishNames(r), ['Salade']);
    });

    test('undeclared allergens exclude a dish for allergic clients only', () {
      final menu = [_dish(1, 1, 'Mystère', allergens: null)];
      final restaurants = [_resto(1, 'R')];
      expect(
          _run(allergens: {'gluten'}, restaurants: restaurants, dishes: menu)
              .dishes,
          isEmpty);
      expect(_dishNames(_run(restaurants: restaurants, dishes: menu)),
          ['Mystère']);
    });

    test('halal client: only halal dishes, and never a restaurant with none',
        () {
      final r = _run(
        diets: {'halal'},
        restaurants: [_resto(1, 'Halal Grill'), _resto(2, 'Porc & Co')],
        dishes: [
          _dish(1, 1, 'Kebab', tags: {'halal'}),
          _dish(2, 1, 'Frites', tags: {'vegan'}),
          _dish(3, 2, 'Jambon', tags: {}),
        ],
      );
      expect(_dishNames(r), ['Kebab']);
      expect(_restaurantNames(r), ['Halal Grill']);
      expect(r.restaurants.single.compatibleDishCount, 1);
    });

    test('several diets must all hold; vegan counts as vegetarian', () {
      final r = _run(
        diets: {'halal', 'vegetarien'},
        restaurants: [_resto(1, 'R')],
        dishes: [
          _dish(1, 1, 'Falafel', tags: {'vegan', 'halal'}),
          _dish(2, 1, 'Omelette', tags: {'vegetarien'}),
          _dish(3, 1, 'Poulet', tags: {'halal'}),
        ],
      );
      expect(_dishNames(r), ['Falafel']);
    });

    test('unavailable dishes are never recommended', () {
      final r = _run(
        restaurants: [_resto(1, 'R')],
        dishes: [
          const RecoDish(
              id: 1, restaurantId: 1, name: 'Épuisé', price: 10,
              isAvailable: false, allergens: {}),
        ],
      );
      expect(r.dishes, isEmpty);
    });

    test('without constraints, restaurants without a menu are still listed',
        () {
      final r = _run(restaurants: [_resto(1, 'Nouveau')], dishes: []);
      expect(_restaurantNames(r), ['Nouveau']);
    });
  });

  // ── 2. Content-based ────────────────────────────────────────────────────────
  group('content-based', () {
    test('cosine similarity', () {
      expect(RecommendationEngine.cosine({'a': 1}, {'a': 3}), closeTo(1, 1e-9));
      expect(RecommendationEngine.cosine({'a': 1}, {'b': 1}), 0);
      expect(RecommendationEngine.cosine({}, {'a': 1}), 0);
      expect(
          RecommendationEngine.cosine({'a': 1, 'b': 1}, {'a': 1}),
          closeTo(1 / 1.4142135623730951, 1e-9));
    });

    test('a client who orders Japanese food gets Japanese places first', () {
      final r = _run(
        restaurants: [
          _resto(1, 'Sushi Bar', 'Japanese'),
          _resto(2, 'Bistrot', 'French'),
          _resto(3, 'Ramen House', 'Japanese'),
        ],
        dishes: [
          _dish(1, 1, 'Sashimi'),
          _dish(2, 2, 'Steak'),
          _dish(3, 3, 'Ramen'),
        ],
        interactions: [_order(_me, 1)],
      );
      final names = _restaurantNames(r);
      expect(names.indexOf('Ramen House'), lessThan(names.indexOf('Bistrot')));
      final ramenHouse =
          r.restaurants.firstWhere((x) => x.restaurant.name == 'Ramen House');
      expect(ramenHouse.breakdown.content, greaterThan(0));
      expect(ramenHouse.reasons.first,
          'Parce que vous aimez la cuisine japonaise');
    });

    test('recent interactions weigh more than old ones', () {
      final r = _run(
        restaurants: [
          _resto(1, 'Sushi Bar', 'Japanese'),
          _resto(2, 'Bistrot', 'French'),
          _resto(3, 'Ramen House', 'Japanese'),
          _resto(4, 'Brasserie', 'French'),
        ],
        dishes: [
          _dish(1, 1, 'Sashimi'),
          _dish(2, 2, 'Steak'),
          _dish(3, 3, 'Ramen'),
          _dish(4, 4, 'Choucroute'),
        ],
        interactions: [
          _order(_me, 1, daysAgo: 1), // Japanese, recent
          _order(_me, 2, daysAgo: 300), // French, ten months ago
        ],
      );
      double content(String name) => r.restaurants
          .firstWhere((x) => x.restaurant.name == name)
          .breakdown
          .content;
      expect(content('Ramen House'), greaterThan(content('Brasserie')));
    });
  });

  // ── 3. Collaborative filtering ──────────────────────────────────────────────
  group('item-based collaborative filtering', () {
    // X, Y, Z in three restaurants with distinct cuisines, so content alone
    // cannot explain the ranking.
    final restaurants = [
      _resto(1, 'RX', 'French'),
      _resto(2, 'RY', 'Mexican'),
      _resto(3, 'RZ', 'Indian'),
    ];
    final dishes = [
      _dish(1, 1, 'Plat X'),
      _dish(2, 2, 'Plat Y'),
      _dish(3, 3, 'Plat Z'),
    ];

    test('clients who like X also like Y → Y recommended with that reason',
        () {
      final r = _run(
        restaurants: restaurants,
        dishes: dishes,
        interactions: [
          _order(_me, 1),
          // Two other clients like both X and Y.
          _order(2, 1), _order(2, 2),
          _order(3, 1), _order(3, 2),
          // A third one only likes Z.
          _order(4, 3), _order(4, 3), _order(4, 3),
        ],
      );
      final y = r.dishes.firstWhere((d) => d.dish.name == 'Plat Y');
      final z = r.dishes.firstWhere((d) => d.dish.name == 'Plat Z');
      expect(y.breakdown.collaborative, greaterThan(0));
      expect(z.breakdown.collaborative, 0);
      expect(_dishNames(r).indexOf('Plat Y'),
          lessThan(_dishNames(r).indexOf('Plat Z')));
      expect(y.reasons.first, 'Apprécié des clients qui aiment Plat X');
    });

    test("only other clients' data counts", () {
      final r = _run(
        restaurants: restaurants,
        dishes: dishes,
        interactions: [_order(_me, 1), _order(_me, 2)],
      );
      expect(r.dishes.every((d) => d.breakdown.collaborative == 0), isTrue);
      expect(r.dishes.every((d) => d.breakdown.popularity == 0), isTrue);
    });
  });

  // ── 4. Cold start ───────────────────────────────────────────────────────────
  group('cold start', () {
    test('no order nor favorite → popularity, with a popularity reason', () {
      final r = _run(
        restaurants: [_resto(1, 'A'), _resto(2, 'B')],
        dishes: [_dish(1, 1, 'Rare'), _dish(2, 2, 'Star')],
        interactions: [
          _order(2, 2), _order(3, 2), _order(4, 2),
          _order(2, 1),
        ],
      );
      expect(r.coldStart, isTrue);
      expect(_dishNames(r), ['Star', 'Rare']);
      expect(_restaurantNames(r), ['B', 'A']);
      expect(r.dishes.first.reasons.first, 'Populaire chez les clients TableGo');
    });

    test('popularity never overrides the hard filters', () {
      final r = _run(
        allergens: {'arachides'},
        restaurants: [_resto(1, 'A')],
        dishes: [
          _dish(1, 1, 'Star aux cacahuètes', allergens: {'arachides'}),
          _dish(2, 1, 'Sûr', allergens: {}),
        ],
        interactions: [_order(2, 1), _order(3, 1)],
      );
      expect(_dishNames(r), ['Sûr']);
    });

    test('no data at all → alphabetical, "À découvrir"', () {
      final r = _run(
        restaurants: [_resto(1, 'Zinc'), _resto(2, 'Atelier')],
        dishes: [],
      );
      expect(_restaurantNames(r), ['Atelier', 'Zinc']);
      expect(r.restaurants.first.reasons, ['À découvrir']);
    });
  });

  // ── 5. Explanations ─────────────────────────────────────────────────────────
  group('explanations', () {
    test('dishes state the diet and allergen guarantee', () {
      final r = _run(
        diets: {'halal', 'vegetarien'},
        allergens: {'arachides'},
        restaurants: [_resto(1, 'R')],
        dishes: [_dish(1, 1, 'Falafel', tags: {'halal', 'vegan'})],
      );
      expect(r.dishes.single.reasons.last,
          'Compatible halal et végétarien, sans arachides');
      expect(r.dishes.single.explanation, contains(' · '));
    });

    test('restaurants state how many dishes are compatible', () {
      final r = _run(
        diets: {'halal'},
        restaurants: [_resto(1, 'R')],
        dishes: [
          _dish(1, 1, 'A', tags: {'halal'}),
          _dish(2, 1, 'B', tags: {'halal'}),
          _dish(3, 1, 'C'),
        ],
      );
      expect(r.restaurants.single.reasons.last, '2 plats compatibles halal');
    });

    test('allergy-only clients get "sans …"', () {
      final r = _run(
        allergens: {'lactose'},
        restaurants: [_resto(1, 'R')],
        dishes: [_dish(1, 1, 'A', allergens: {})],
      );
      expect(r.dishes.single.reasons.last, 'Sans lactose');
      expect(r.restaurants.single.reasons.last, '1 plat sans lactose');
    });

    test('a favorite restaurant is explained as such', () {
      final r = _run(
        restaurants: [_resto(1, 'Chez Moi', 'French')],
        dishes: [_dish(1, 1, 'Plat du jour')],
        interactions: [_favResto(_me, 1)],
      );
      expect(r.coldStart, isFalse);
      expect(r.restaurants.single.reasons.first,
          anyOf('Un restaurant que vous appréciez déjà',
              'Parce que vous aimez la cuisine française'));
    });
  });

  test('limits: at most 10 restaurants and 10 dishes', () {
    final r = _run(
      restaurants: [for (var i = 1; i <= 12; i++) _resto(i, 'R$i')],
      dishes: [for (var i = 1; i <= 12; i++) _dish(i, i, 'D$i')],
    );
    expect(r.restaurants, hasLength(10));
    expect(r.dishes, hasLength(10));
  });
}
