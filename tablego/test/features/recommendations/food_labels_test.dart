import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/features/recommendations/domain/food_labels.dart';

void main() {
  group('FoodLabels.canonical', () {
    test('ignores case, accents, dashes and extra spaces', () {
      expect(FoodLabels.canonical('Végétarien'), 'vegetarien');
      expect(FoodLabels.canonical('  VÉGÉTARIEN '), 'vegetarien');
      expect(FoodLabels.canonical('Fruits-à-coque'), 'fruits a coque');
      expect(FoodLabels.canonical('Œufs'), 'oeufs');
      // Decomposed accent (e + combining acute).
      expect(FoodLabels.canonical('végétarien'), 'vegetarien');
    });

    test('maps the profile screen English values to French names', () {
      expect(FoodLabels.canonical('vegetarian'), 'vegetarien');
      expect(FoodLabels.canonical('peanuts'), 'arachides');
      expect(FoodLabels.canonical('dairy'), 'lactose');
      expect(FoodLabels.canonical('eggs'), 'oeufs');
      expect(FoodLabels.canonical('tree nuts'), 'fruits a coque');
      expect(FoodLabels.canonical('gluten-free'), 'sans gluten');
      expect(FoodLabels.canonical('kosher'), 'casher');
    });

    test('maps French synonyms too and keeps unknown labels normalised', () {
      expect(FoodLabels.canonical('Cacahuètes'), 'arachides');
      expect(FoodLabels.canonical('Produits laitiers'), 'lactose');
      expect(FoodLabels.canonical('Épices'), 'epices');
    });

    test('canonicalSet de-duplicates synonyms and drops blanks', () {
      expect(FoodLabels.canonicalSet(['Peanuts', 'arachides', ' ', 'GLUTEN']),
          {'arachides', 'gluten'});
    });
  });

  group('FoodLabels.satisfiesDiet', () {
    test('vegan satisfies vegetarian, vegetarian satisfies pescetarian', () {
      expect(FoodLabels.satisfiesDiet('vegetarien', {'vegan'}, {}), isTrue);
      expect(FoodLabels.satisfiesDiet('pescetarien', {'vegetarien'}, {}),
          isTrue);
      expect(FoodLabels.satisfiesDiet('vegan', {'vegetarien'}, {}), isFalse);
    });

    test('halal needs the halal tag', () {
      expect(FoodLabels.satisfiesDiet('halal', {'halal'}, {}), isTrue);
      expect(FoodLabels.satisfiesDiet('halal', {'vegan'}, {}), isFalse);
    });

    test('gluten-free: tag, or declared allergens without gluten', () {
      expect(FoodLabels.satisfiesDiet('sans gluten', {}, {'lactose'}), isTrue);
      expect(FoodLabels.satisfiesDiet('sans gluten', {}, {'gluten'}), isFalse);
      expect(FoodLabels.satisfiesDiet('sans gluten', {}, null), isFalse);
      expect(FoodLabels.satisfiesDiet('sans gluten', {'sans gluten'}, null),
          isTrue);
    });
  });

  test('French display helpers', () {
    expect(FoodLabels.display('vegetarien'), 'végétarien');
    expect(FoodLabels.display('fruits a coque'), 'fruits à coque');
    expect(FoodLabels.cuisineDisplay('Japanese'), 'japonaise');
    expect(FoodLabels.cuisineDisplay('Française'), 'française');
    expect(FoodLabels.joinFr(['halal']), 'halal');
    expect(FoodLabels.joinFr(['halal', 'végétarien']), 'halal et végétarien');
    expect(FoodLabels.joinFr(['a', 'b', 'c']), 'a, b et c');
  });
}
