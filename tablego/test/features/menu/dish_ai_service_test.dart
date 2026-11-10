import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tablego/features/menu/data/models/dish_model.dart';
import 'package:tablego/features/menu/services/dish_ai_service.dart';

/// A Gemini generateContent response whose text part is [text].
String _geminiBody(String text) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    });

void main() {
  group('local fallback', () {
    Set<String> allergens(String name) => DishAiService.detectAllergens(name);

    test('detects allergens from French and English keywords', () {
      expect(allergens('Pizza Margherita'), {'gluten', 'lactose'});
      expect(allergens('Croque-monsieur'), {'gluten', 'lactose'});
      expect(allergens('Crème brûlée'), {'lactose', 'oeufs'});
      expect(allergens('Brik au thon et œuf'),
          {'gluten', 'oeufs', 'poisson'});
      expect(allergens('Shrimp pasta with cheese'),
          {'gluten', 'lactose', 'crustaces'});
      expect(allergens('Salade de crevettes'), {'crustaces'});
      expect(allergens('Peanut butter cookie'),
          {'gluten', 'arachides'});
      expect(allergens('Baklava aux pistaches'),
          {'gluten', 'fruits a coque'});
      expect(allergens('Houmous'), {'sesame'});
    });

    test('whole words only: laitue is not lait, épinards is not pain', () {
      expect(allergens('Salade laitue épinards'), isEmpty);
      expect(allergens('Tajine agneau'), isEmpty); // "eau" ≠ "agneau"
    });

    test('suggestion: specific description, category, labels', () {
      final pizza = DishAiService.localSuggestion('Pizza Margherita');
      expect(pizza.source, SuggestionSource.local);
      expect(pizza.category, 'Plat principal');
      expect(pizza.description, startsWith('Pizza Margherita : '));
      expect(pizza.description, contains('mozzarella'));
      expect(pizza.description, contains('tomate'));
      expect(pizza.allergens, ['Gluten', 'Lactose']);

      final dessert = DishAiService.localSuggestion('Crème brûlée');
      expect(dessert.category, 'Dessert');
      expect(dessert.allergensLabel, 'Lactose, Œufs');

      expect(DishAiService.localSuggestion('Thé à la menthe').category,
          'Boisson');
      expect(DishAiService.localSuggestion('Soupe du jour').category,
          'Entrée');
      expect(DishAiService.localSuggestion('Tajine agneau').allergens,
          ['Aucun']);
    });

    test('a category chosen by the restaurant is kept', () {
      expect(
          DishAiService.localSuggestion('Pizza', category: 'Spécialité')
              .category,
          'Spécialité');
    });

    test('labels round-trip to the JSON stored in dishes.allergens', () {
      final s = DishAiService.localSuggestion('Brik au thon et œuf');
      expect(DishModel.allergensToDb(s.allergensLabel),
          '["gluten","oeufs","poisson"]');
      expect(
          DishModel.allergensToDb(
              DishAiService.localSuggestion('Tajine').allergensLabel),
          '[]');
    });
  });

  group('Gemini response parsing', () {
    test('valid JSON: description, category, allergens from our list', () {
      final s = DishAiService.parseGeminiResponse(_geminiBody(jsonEncode({
        'description': 'Pâte fine, sauce tomate et mozzarella fondante.',
        'category': 'Plat principal',
        'allergens': ['gluten', 'lactose'],
      })))!;
      expect(s.source, SuggestionSource.gemini);
      expect(s.description, 'Pâte fine, sauce tomate et mozzarella fondante.');
      expect(s.category, 'Plat principal');
      expect(s.allergens, ['Gluten', 'Lactose']);
    });

    test('markdown fences and synonyms are tolerated; unknown values '
        'dropped', () {
      final s = DishAiService.parseGeminiResponse(_geminiBody(
          'Voici :\n```json\n{"description":"Crevettes sautées.",'
          '"category":"Plat du chef","allergens":["Shellfish","Lait",'
          '"plutonium"]}\n```'))!;
      expect(s.category, 'Plat principal'); // unknown → default
      expect(s.allergens, ['Lactose', 'Crustacés']);
    });

    test('the category chosen by the restaurant wins', () {
      final s = DishAiService.parseGeminiResponse(
          _geminiBody('{"description":"x","category":"Dessert"}'),
          category: 'Snack')!;
      expect(s.category, 'Snack');
      expect(s.allergens, ['Aucun']);
    });

    test('unusable replies return null (→ fallback)', () {
      for (final body in [
        'not json',
        '{}',
        jsonEncode({'candidates': []}),
        _geminiBody('pas de JSON ici'),
        _geminiBody('{"category":"Dessert"}'), // no description
        _geminiBody('{"description": ""}'),
        _geminiBody('{broken'),
      ]) {
        expect(DishAiService.parseGeminiResponse(body), isNull, reason: body);
      }
    });

    test('the prompt carries the dish name, the category and our allergen '
        'list', () {
      final prompt = DishAiService.buildPrompt('Couscous royal',
          category: 'Spécialité');
      expect(prompt, contains('"Couscous royal"'));
      expect(prompt, contains('Spécialité'));
      for (final id in DishAiService.allergenIds) {
        expect(prompt, contains('"$id"'));
      }
    });
  });

  group('suggestFromName (HTTP mocked)', () {
    test('no key → local fallback, no HTTP call', () async {
      var calls = 0;
      final service = DishAiService(
        apiKey: '',
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
      );
      final s = await service.suggestFromName('Pizza Margherita');
      expect(s.source, SuggestionSource.local);
      expect(calls, 0);
    });

    test('Gemini answers → its suggestion; request carries the key and the '
        'dish name', () async {
      late http.Request seen;
      final service = DishAiService(
        apiKey: 'test-key',
        models: ['m1'],
        client: MockClient((request) async {
          seen = request;
          return http.Response(
              _geminiBody('{"description":"Lasagnes au four.",'
                  '"category":"Plat principal",'
                  '"allergens":["gluten","lactose","oeufs"]}'),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );
      final s = await service.suggestFromName('Lasagnes');
      expect(s.source, SuggestionSource.gemini);
      expect(s.allergens, ['Gluten', 'Lactose', 'Œufs']);
      expect(seen.url.path, endsWith('/m1:generateContent'));
      expect(seen.headers['x-goog-api-key'], 'test-key');
      expect(seen.body, contains('Lasagnes'));
    });

    test('first model fails (503), second answers', () async {
      final tried = <String>[];
      final service = DishAiService(
        apiKey: 'k',
        models: ['busy', 'ok'],
        client: MockClient((request) async {
          tried.add(request.url.pathSegments.last);
          return request.url.path.contains('busy')
              ? http.Response('overloaded', 503)
              : http.Response(_geminiBody('{"description":"Ok."}'), 200);
        }),
      );
      final s = await service.suggestFromName('Soupe');
      expect(s.source, SuggestionSource.gemini);
      expect(tried, ['busy:generateContent', 'ok:generateContent']);
    });

    test('every model fails or replies garbage → local fallback', () async {
      final service = DishAiService(
        apiKey: 'k',
        models: ['a', 'b'],
        client: MockClient((request) async => request.url.path.contains('a')
            ? http.Response('nope', 404)
            : http.Response(_geminiBody('no json'), 200)),
      );
      final s = await service.suggestFromName('Pizza Margherita');
      expect(s.source, SuggestionSource.local);
      expect(s.allergens, ['Gluten', 'Lactose']);
    });

    test('network error → local fallback', () async {
      final service = DishAiService(
        apiKey: 'k',
        models: ['a'],
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      expect((await service.suggestFromName('Croque-monsieur')).source,
          SuggestionSource.local);
    });
  });

  group('key from the git-ignored assets/config/gemini.json', () {
    String ok(String text) => _geminiBody(text);

    test('the key in the local config is used (no --dart-define)', () async {
      late http.Request seen;
      final service = DishAiService(
        bundle: _FakeBundle({
          DishAiService.localConfigAsset: '{"GEMINI_API_KEY": "file-key"}',
        }),
        client: MockClient((r) async {
          seen = r;
          return http.Response(ok('{"description":"Ok."}'), 200);
        }),
      );
      expect(await service.hasApiKey(), isTrue);
      final s = await service.suggestFromName('Pizza');
      expect(s.source, SuggestionSource.gemini);
      expect(seen.headers['x-goog-api-key'], 'file-key');
      expect(seen.url.path,
          endsWith('/${DishAiService.defaultModels.first}:generateContent'));
    });

    test('GEMINI_MODEL in the file forces the model', () async {
      late Uri url;
      final service = DishAiService(
        bundle: _FakeBundle({
          DishAiService.localConfigAsset:
              '{"GEMINI_API_KEY": "k", "GEMINI_MODEL": "gemini-forced"}',
        }),
        client: MockClient((r) async {
          url = r.url;
          return http.Response(ok('{"description":"Ok."}'), 200);
        }),
      );
      await service.suggestFromName('Pizza');
      expect(url.path, endsWith('/gemini-forced:generateContent'));
    });

    test('no file, the example placeholder, or broken JSON → fallback, no '
        'HTTP call', () async {
      for (final files in [
        <String, String>{},
        {
          DishAiService.localConfigAsset:
              '{"GEMINI_API_KEY": "colle-ta-cle-ici (https://aistudio.google.com)"}',
        },
        {DishAiService.localConfigAsset: '{not json'},
      ]) {
        var calls = 0;
        final service = DishAiService(
          bundle: _FakeBundle(files),
          client: MockClient((_) async {
            calls++;
            return http.Response('', 500);
          }),
        );
        expect(await service.hasApiKey(), isFalse, reason: '$files');
        expect((await service.suggestFromName('Pizza')).source,
            SuggestionSource.local);
        expect(calls, 0);
      }
    });

    test('an explicit key (argument) wins and the file is not read', () async {
      final bundle = _FakeBundle({
        DishAiService.localConfigAsset: '{"GEMINI_API_KEY": "file-key"}',
      });
      final service = DishAiService(apiKey: '', bundle: bundle);
      expect(await service.hasApiKey(), isFalse);
      expect(bundle.reads, 0);
    });
  });
}

/// In-memory asset bundle; a missing key throws like the real one.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;
  int reads = 0;

  @override
  Future<ByteData> load(String key) async {
    reads++;
    final content = files[key];
    if (content == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(content)));
  }
}
