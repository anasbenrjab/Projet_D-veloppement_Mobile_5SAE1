import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// AI service for the Dish Assistant feature.
///
/// PRIMARY  → Google Gemini 2.0 Flash API (external web service)
/// FALLBACK → local keyword heuristics (works offline)
///
/// Valeur Ajoutée: consommation d'un web service externe (Gemini API)
class DishAiService {
  DishAiService._();
  static final DishAiService instance = DishAiService._();

  // ── Gemini config ──────────────────────────────────────────────────────────
  // The key is NOT stored in the code (the repo is public). It is read at
  // build time from secrets.json (git-ignored):
  //   flutter run -d chrome --dart-define-from-file=secrets.json
  // Without a key, the assistant uses the local suggestion fallback.
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  // AQ. format keys use x-goog-api-key header (new Google Auth key format)
  // Try models in order: highest quota first
  // Model names confirmed from API ListModels response
  static const List<String> _models = [
    'gemini-3.8-flash',       // latest, recommended by Google
    'gemini-3.5-flash-lite',  // lite fallback (more quota)
    'gemini-3.1-flash-lite',  // older stable fallback
  ];
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/';

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Analyse a dish name and return a suggestion.
  /// Tries Gemini first; falls back to local heuristics on any failure.
  Future<DishSuggestion> suggestFromName(String dishName) async {
    try {
      final result = await _callGemini(dishName);
      if (result != null) return result;
    } catch (e) {
      debugPrint('[DishAI] Gemini failed: $e — using local fallback');
    }
    return _localSuggestion(dishName);
  }

  /// Returns category suggestions for combos.
  List<String> suggestCombos(String category) {
    const combos = <String, List<String>>{
      'Entrée': ['Plat principal', 'Boisson'],
      'Plat principal': ['Dessert', 'Boisson'],
      'Dessert': ['Boisson'],
      'Boisson': ['Snack', 'Dessert'],
      'Snack': ['Boisson'],
    };
    return combos[category] ?? ['Boisson'];
  }

  // ── Gemini call ─────────────────────────────────────────────────────────────

  Future<DishSuggestion?> _callGemini(String dishName) async {
    if (_apiKey.isEmpty) {
      debugPrint('[DishAI] No GEMINI_API_KEY (see secrets.json) — local fallback');
      return null;
    }
    final prompt = '''
Tu es un assistant culinaire expert pour une application de restaurant.
Analyse le nom du plat suivant et réponds UNIQUEMENT avec un JSON valide (sans markdown, sans explication) :

Plat : "$dishName"

Format JSON attendu :
{
  "description": "<description appétissante en français, 1-2 phrases>",
  "category": "<une seule valeur parmi : Entrée, Plat principal, Dessert, Boisson, Snack, Menu enfant, Spécialité>",
  "allergens": ["<allergène1>", "<allergène2>"]
}

Pour les allergènes, utilise uniquement : Gluten, Lait, Œuf, Poisson, Crustacés, Arachides, Fruits à coque, Soja, Céleri, Sésame, Moutarde, Lupin, Mollusques, Sulfites.
Si aucun allergène probable, mets ["Aucun"].
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 300,
      },
    });

    // Try each model until one succeeds
    for (final model in _models) {
      final url = '$_baseUrl$model:generateContent';
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _apiKey,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          debugPrint('[DishAI] Success with model: $model');
          final decoded =
              jsonDecode(response.body) as Map<String, dynamic>;
          final text = decoded['candidates']?[0]?['content']?['parts']
              ?[0]?['text'] as String?;
          if (text == null) continue;

          final clean =
              text.replaceAll(RegExp(r'```json|```'), '').trim();
          final parsed = jsonDecode(clean) as Map<String, dynamic>;

          final description = parsed['description'] as String? ?? '';
          final category =
              parsed['category'] as String? ?? 'Plat principal';
          final rawAllergens = parsed['allergens'];
          final allergens = rawAllergens is List
              ? rawAllergens.map((e) => e.toString()).toList()
              : <String>['Aucun'];

          return DishSuggestion(
            description: description,
            category: category,
            allergens: allergens,
            source: SuggestionSource.gemini,
          );
        } else if (response.statusCode == 503 ||
            response.statusCode == 429) {
          // Overloaded or rate limited — try next model
          debugPrint(
              '[DishAI] Model $model returned ${response.statusCode}, trying next...');
          continue;
        } else {
          debugPrint(
              '[DishAI] Model $model HTTP ${response.statusCode}: ${response.body}');
          continue;
        }
      } catch (e) {
        debugPrint('[DishAI] Model $model error: $e, trying next...');
        continue;
      }
    }
    return null; // all models failed → fallback to local
  }

  // ── Local fallback ──────────────────────────────────────────────────────────

  DishSuggestion _localSuggestion(String dishName) {
    final name = dishName.toLowerCase().trim();
    final category = _detectCategory(name);
    final allergens = _detectAllergens(name);
    final description = _generateDescription(name, category);

    return DishSuggestion(
      description: description,
      category: category,
      allergens: allergens,
      source: SuggestionSource.local,
    );
  }

  String _detectCategory(String name) {
    if (_matchesAny(name, _dessertKeywords)) return 'Dessert';
    if (_matchesAny(name, _drinkKeywords)) return 'Boisson';
    if (_matchesAny(name, _starterKeywords)) return 'Entrée';
    if (_matchesAny(name, _snackKeywords)) return 'Snack';
    return 'Plat principal';
  }

  List<String> _detectAllergens(String name) {
    final found = <String>[];
    _allergenMap.forEach((allergen, keywords) {
      if (_matchesAny(name, keywords)) found.add(allergen);
    });
    return found.isEmpty ? ['Aucun'] : found;
  }

  String _generateDescription(String name, String category) {
    final base = _baseDescriptions[category] ??
        _baseDescriptions['Plat principal']!;
    final extras = <String>[];

    if (_matchesAny(name, ['poulet', 'chicken'])) {
      extras.add('poulet tendre et moelleux');
    } else if (_matchesAny(name, ['bœuf', 'beef', 'steak', 'burger'])) {
      extras.add('viande de bœuf sélectionnée');
    } else if (_matchesAny(name, ['poisson', 'saumon', 'thon', 'fish'])) {
      extras.add('poisson frais du jour');
    } else if (_matchesAny(name, ['végé', 'vegetar', 'vegan'])) {
      extras.add('ingrédients 100 % végétariens');
    } else if (_matchesAny(name, ['agneau', 'lamb'])) {
      extras.add('agneau tendre mijoté aux épices');
    } else if (_matchesAny(name, ['pâtes', 'spaghetti', 'tagliatelle', 'pasta'])) {
      extras.add('pâtes cuites al dente');
    } else if (_matchesAny(name, ['pizza'])) {
      extras.add('pâte fine croustillante garnie');
    } else if (_matchesAny(name, ['salade', 'salad'])) {
      extras.add('légumes frais de saison');
    } else if (_matchesAny(name, ['couscous'])) {
      extras.add('semoule fine avec légumes et viandes');
    } else if (_matchesAny(name, ['tajine', 'tagine'])) {
      extras.add('cuisson lente au tajine traditionnel');
    }

    if (extras.isEmpty) {
      return '$base Préparé avec soin par notre chef avec des ingrédients frais.';
    }
    return '$base Préparé avec ${extras.join(', ')}, '
        'sélectionné avec soin pour vous offrir le meilleur.';
  }

  bool _matchesAny(String text, List<String> keywords) =>
      keywords.any((kw) => text.contains(kw));

  // ── Keyword tables ──────────────────────────────────────────────────────────

  static const _dessertKeywords = [
    'gâteau', 'cake', 'tarte', 'mousse', 'crème', 'glace', 'sorbet',
    'tiramisu', 'brownie', 'macaron', 'éclair', 'fondant', 'mille-feuille',
    'charlotte', 'pannacotta', 'cheesecake', 'flan', 'pudding', 'baklava',
    'halwa', 'dessert',
  ];

  static const _drinkKeywords = [
    'jus', 'café', 'thé', 'lait', 'eau', 'smoothie', 'limonade', 'boisson',
    'soda', 'citronnade', 'milk-shake', 'juice', 'coffee', 'tea', 'drink',
    'cocktail', 'infusion', 'expresso', 'cappuccino', 'latte',
  ];

  static const _starterKeywords = [
    'soupe', 'salade', 'entrée', 'velouté', 'bruschetta', 'carpaccio',
    'tartare', 'tapas', 'mezze', 'houmous', 'brik', 'samoussa',
  ];

  static const _snackKeywords = [
    'sandwich', 'panini', 'wrap', 'toast', 'croissant', 'snack', 'nuggets',
  ];

  static const _allergenMap = <String, List<String>>{
    'Gluten': [
      'pain', 'pâte', 'farine', 'blé', 'semoule', 'pizza', 'burger',
      'sandwich', 'brioche', 'couscous', 'pasta', 'spaghetti', 'croissant',
    ],
    'Lait': [
      'fromage', 'crème', 'beurre', 'lait', 'gratin', 'lasagne', 'pizza',
      'tiramisu', 'crêpe', 'fondue', 'milk-shake', 'cappuccino', 'latte',
      'cheesecake',
    ],
    'Œuf': [
      'œuf', 'omelette', 'quiche', 'mayonnaise', 'flan', 'crêpe', 'carbonara',
    ],
    'Poisson': [
      'poisson', 'saumon', 'thon', 'cabillaud', 'anchois', 'sardine',
    ],
    'Crustacés': [
      'crevette', 'homard', 'crabe', 'langouste', 'fruits de mer', 'paella',
    ],
    'Arachides': ['cacahuète', 'arachide', 'peanut', 'satay'],
    'Fruits à coque': [
      'amande', 'noix', 'noisette', 'pistache', 'cajou', 'baklava', 'praline',
    ],
    'Soja': ['soja', 'tofu', 'miso', 'edamame'],
    'Sésame': ['sésame', 'tahini', 'houmous'],
  };

  static const _baseDescriptions = <String, String>{
    'Entrée': 'Une entrée délicate pour ouvrir l\'appétit.',
    'Plat principal': 'Un plat généreux et savoureux au cœur de notre carte.',
    'Dessert': 'Une douceur sucrée pour terminer le repas en beauté.',
    'Boisson': 'Une boisson rafraîchissante pour accompagner votre repas.',
    'Snack': 'Un encas rapide et gourmand à déguster à toute heure.',
    'Menu enfant': 'Un menu équilibré conçu pour les plus petits.',
    'Spécialité': 'Notre spécialité maison, préparée selon une recette unique.',
  };
}

// ─── Enums & DTO ─────────────────────────────────────────────────────────────

enum SuggestionSource { gemini, local }

class DishSuggestion {
  final String description;
  final String category;
  final List<String> allergens;
  final SuggestionSource source;

  const DishSuggestion({
    required this.description,
    required this.category,
    required this.allergens,
    this.source = SuggestionSource.local,
  });

  String get allergensLabel => allergens.join(', ');

  /// Whether the suggestion came from Gemini (external API) or local heuristics.
  bool get isAiGenerated => source == SuggestionSource.gemini;
}
