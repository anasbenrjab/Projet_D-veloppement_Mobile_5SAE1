import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;

import '../../recommendations/domain/food_labels.dart';

/// AI service for the Dish Assistant feature.
///
/// PRIMARY  → Google Gemini API (external web service)
/// FALLBACK → local keyword heuristics (works offline)
///
/// Valeur Ajoutée: consommation d'un web service externe (Gemini API)
///
/// Every call logs the path it took: `[DishAI] path=gemini model=…` or
/// `[DishAI] path=fallback reason=…` (no key, HTTP error, unusable reply).
class DishAiService {
  DishAiService({
    http.Client? client,
    String? apiKey,
    List<String>? models,
    this._bundle,
  })  : _client = client ?? http.Client(),
        _explicitKey = apiKey,
        _explicitModels = models;

  static final DishAiService instance = DishAiService();

  // ── Gemini config ──────────────────────────────────────────────────────────
  // The key is NOT stored in the code (the repo is public).  Where it comes
  // from, first match wins:
  //   1. --dart-define GEMINI_API_KEY (e.g. --dart-define-from-file=secrets.json)
  //   2. assets/config/gemini.json — git-ignored, copy gemini.example.json;
  //      read once at the first generation, so a plain `flutter run` works.
  // No key → the local fallback is used.
  static const String _keyFromEnvironment =
      String.fromEnvironment('GEMINI_API_KEY');
  static const String _modelFromEnvironment =
      String.fromEnvironment('GEMINI_MODEL');

  /// Git-ignored local config: {"GEMINI_API_KEY": "...", "GEMINI_MODEL": ""}.
  static const String localConfigAsset = 'assets/config/gemini.json';

  // Models tried in order (first that answers wins); "GEMINI_MODEL" forces
  // one.  All listed by the Gemini ListModels API in November 2026.
  static const List<String> defaultModels = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-flash-latest',
  ];

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/';

  final http.Client _client;
  final String? _explicitKey;
  final List<String>? _explicitModels;
  final AssetBundle? _bundle;

  String _apiKey = '';
  List<String> _models = defaultModels;
  bool _configLoaded = false;

  /// Resolves the key and models once (see the order above).
  Future<void> _loadConfig() async {
    if (_configLoaded) return;
    _configLoaded = true;

    var key = _explicitKey ?? _keyFromEnvironment;
    var model = _modelFromEnvironment;
    var source = _explicitKey != null ? 'argument' : '--dart-define';

    if (_explicitKey == null && key.isEmpty) {
      try {
        final raw = await (_bundle ?? rootBundle).loadString(localConfigAsset);
        final json = jsonDecode(raw);
        if (json is Map) {
          final fromFile = (json['GEMINI_API_KEY'] ?? '').toString().trim();
          // The example file's placeholder contains spaces: not a key.
          if (fromFile.isNotEmpty && !fromFile.contains(' ')) {
            key = fromFile;
            source = localConfigAsset;
          }
          if (model.isEmpty) {
            model = (json['GEMINI_MODEL'] ?? '').toString().trim();
          }
        }
      } catch (_) {
        // No local config file: normal for teammates without a key.
      }
    }

    _apiKey = key;
    _models = _explicitModels ?? (model.isNotEmpty ? [model] : defaultModels);
    debugPrint(_apiKey.isEmpty
        ? '[DishAI] no Gemini key (no --dart-define, no $localConfigAsset)'
        : '[DishAI] Gemini key from $source, models: ${_models.join(', ')}');
  }

  /// True when a Gemini key is available (after the config is loaded).
  Future<bool> hasApiKey() async {
    await _loadConfig();
    return _apiKey.isNotEmpty;
  }

  /// Allergen vocabulary shared with the recommender (canonical names, see
  /// docs/integration-recommandations.md).
  static const List<String> allergenIds = [
    'gluten', 'lactose', 'oeufs', 'poisson', 'crustaces', 'arachides',
    'fruits a coque', 'soja', 'sesame', 'moutarde', 'celeri',
  ];

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Analyse a dish name (and its category when the restaurant chose one)
  /// and return a suggestion.  Tries Gemini first; falls back to local
  /// heuristics on any failure.
  Future<DishSuggestion> suggestFromName(String dishName,
      {String? category}) async {
    if (!await hasApiKey()) {
      debugPrint('[DishAI] path=fallback reason=no GEMINI_API_KEY '
          '(--dart-define or $localConfigAsset)');
      return localSuggestion(dishName, category: category);
    }
    try {
      final result = await _callGemini(dishName, category: category);
      if (result != null) return result;
      debugPrint('[DishAI] path=fallback reason=no usable Gemini reply');
    } catch (e) {
      debugPrint('[DishAI] path=fallback reason=$e');
    }
    return localSuggestion(dishName, category: category);
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

  @visibleForTesting
  static String buildPrompt(String dishName, {String? category}) => '''
Tu es un assistant culinaire pour la carte d'un restaurant.
Plat : "$dishName"${category != null ? '\nCatégorie choisie par le restaurant : "$category"' : ''}

Réponds UNIQUEMENT avec un objet JSON (sans markdown) :
{
  "description": "<1 à 2 phrases en français, spécifiques à CE plat : ses ingrédients typiques et sa préparation ; pas de phrase générique>",
  "category": "<${category ?? 'une valeur parmi : Entrée, Plat principal, Dessert, Boisson, Snack, Menu enfant, Spécialité'}>",
  "allergens": [<allergènes probables, uniquement parmi : ${allergenIds.map((a) => '"$a"').join(', ')}>]
}
Si le plat ne contient probablement aucun de ces allergènes, renvoie "allergens": [].
''';

  Future<DishSuggestion?> _callGemini(String dishName,
      {String? category}) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': buildPrompt(dishName, category: category)}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 400,
        'responseMimeType': 'application/json',
      },
    });

    // Try each model until one succeeds
    for (final model in _models) {
      try {
        final response = await _client
            .post(
              Uri.parse('$_baseUrl$model:generateContent'),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _apiKey,
              },
              body: body,
            )
            // Per model: an overloaded model must not block the next one.
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          // 503 overloaded / 429 rate limited / 404 unknown model → next one
          debugPrint('[DishAI] model=$model HTTP ${response.statusCode}, '
              'trying next…');
          continue;
        }
        final suggestion =
            parseGeminiResponse(response.body, category: category);
        if (suggestion == null) {
          debugPrint('[DishAI] model=$model unusable reply, trying next…');
          continue;
        }
        debugPrint('[DishAI] path=gemini model=$model');
        return suggestion;
      } catch (e) {
        debugPrint('[DishAI] model=$model error: $e, trying next…');
      }
    }
    return null; // all models failed → fallback to local
  }

  /// Parses a Gemini `generateContent` response body.  Returns null when it
  /// holds no usable suggestion (no text, no JSON object, no description).
  /// Unknown categories and allergens outside [allergenIds] are dropped.
  @visibleForTesting
  static DishSuggestion? parseGeminiResponse(String responseBody,
      {String? category}) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) return null;
      final candidates = decoded['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final first = candidates.first;
      final content = first is Map ? first['content'] : null;
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List || parts.isEmpty || parts.first is! Map) return null;
      final text = parts.first['text'];
      if (text is! String) return null;

      // Tolerate ```json fences or text around the object.
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end <= start) return null;
      final parsed = jsonDecode(text.substring(start, end + 1));
      if (parsed is! Map) return null;

      final description = (parsed['description'] as Object?)?.toString().trim();
      if (description == null || description.isEmpty) return null;

      final proposed = parsed['category']?.toString().trim();
      final resolvedCategory = category ??
          (_categories.contains(proposed) ? proposed! : 'Plat principal');

      final raw = parsed['allergens'];
      final allergens = <String>{
        if (raw is List)
          for (final a in raw)
            if (allergenIds.contains(FoodLabels.canonical(a.toString())))
              FoodLabels.canonical(a.toString()),
      };

      return DishSuggestion(
        description: description,
        category: resolvedCategory,
        allergens: _labels(allergens),
        source: SuggestionSource.gemini,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Local fallback ──────────────────────────────────────────────────────────

  /// Offline suggestion: category, allergens and description derived from
  /// the dish name (French and English keywords).
  @visibleForTesting
  static DishSuggestion localSuggestion(String dishName, {String? category}) {
    final text = ' ${FoodLabels.normalize(dishName)} ';
    final resolvedCategory = category ?? _detectCategory(text);
    return DishSuggestion(
      description: _describe(dishName.trim(), text, resolvedCategory),
      category: resolvedCategory,
      allergens: _labels(detectAllergens(dishName)),
      source: SuggestionSource.local,
    );
  }

  /// Canonical allergens (see [allergenIds]) suggested by the words of
  /// [dishName].
  @visibleForTesting
  static Set<String> detectAllergens(String dishName) {
    final text = ' ${FoodLabels.normalize(dishName)} ';
    // "Peanut butter" / "beurre de cacahuète" is not dairy.
    final dairyText = text.replaceAll(
        RegExp(r'peanut butter|beurre de cacahuetes?'), ' ');
    return {
      for (final e in _allergenKeywords.entries)
        if (_hasAny(e.key == 'lactose' ? dairyText : text, e.value)) e.key,
    };
  }

  static String _detectCategory(String text) {
    if (_hasAny(text, _dessertKeywords)) return 'Dessert';
    if (_hasAny(text, _drinkKeywords)) return 'Boisson';
    if (_hasAny(text, _starterKeywords)) return 'Entrée';
    if (_hasAny(text, _snackKeywords)) return 'Snack';
    return 'Plat principal';
  }

  /// "Pizza Margherita : pâte à pizza, tomate et mozzarella. Plat principal
  /// préparé à la minute par notre chef."
  static String _describe(String name, String text, String category) {
    final ingredients = [
      for (final e in _ingredientPhrases.entries)
        if (_hasAny(text, e.value)) e.key,
    ];
    final intro = _categoryPhrases[category] ?? _categoryPhrases['Plat principal']!;
    if (ingredients.isEmpty) return '$name : $intro';
    final list = ingredients.length == 1
        ? ingredients.first
        : '${ingredients.sublist(0, ingredients.length - 1).join(', ')} '
            'et ${ingredients.last}';
    return '$name : ${list[0].toUpperCase()}${list.substring(1)}. $intro';
  }

  /// Whole-word match (plural "s"/"x" allowed) on normalised text, so
  /// "laitue" is not "lait" and "épinards" is not "pain".
  static bool _hasAny(String text, List<String> keywords) => keywords.any(
      (k) => RegExp('(^|[^a-z])${RegExp.escape(FoodLabels.normalize(k))}'
              '[sx]?(?=[^a-z]|\$)')
          .hasMatch(text));

  static List<String> _labels(Set<String> canonical) => canonical.isEmpty
      ? const ['Aucun']
      : [
          for (final id in allergenIds)
            if (canonical.contains(id)) _capitalize(FoodLabels.display(id)),
        ];

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static const _categories = [
    'Entrée', 'Plat principal', 'Dessert', 'Boisson', 'Snack',
    'Menu enfant', 'Spécialité',
  ];

  // ── Keyword tables (normalised: lowercase, no accents) ─────────────────────

  static const _allergenKeywords = <String, List<String>>{
    'gluten': [
      'pain', 'pates', 'pasta', 'spaghetti', 'tagliatelle', 'penne',
      'lasagne', 'ravioli', 'nouille', 'noodle', 'pizza', 'farine', 'flour',
      'ble', 'wheat', 'semoule', 'couscous', 'burger', 'bun', 'sandwich',
      'panini', 'croque', 'croissant', 'brioche', 'baguette', 'bread',
      'toast', 'wrap', 'crepe', 'gaufre', 'waffle', 'quiche', 'tarte', 'pie',
      'gateau', 'cake', 'biscuit', 'cookie', 'brownie', 'beignet', 'donut',
      'brick', 'brik', 'makroudh', 'baklava', 'pane', 'panure', 'chapelure',
      'lablabi', 'tempura', 'nugget', 'biere', 'beer', 'seitan', 'boulgour',
    ],
    'lactose': [
      'lait', 'milk', 'fromage', 'cheese', 'creme', 'cream', 'beurre',
      'butter', 'yaourt', 'yogurt', 'mozzarella', 'parmesan', 'emmental',
      'gruyere', 'cheddar', 'chevre', 'feta', 'ricotta', 'mascarpone',
      'burrata', 'raclette', 'fondue', 'bechamel', 'gratin', 'croque',
      'margherita', 'quatre fromages', 'pizza', 'lasagne', 'carbonara',
      'tiramisu', 'cheesecake', 'glace', 'ice cream', 'latte', 'cappuccino',
      'milkshake', 'milk-shake', 'panna cotta', 'flan', 'caramel', 'alfredo',
      'cheeseburger', 'quiche',
    ],
    'oeufs': [
      'oeuf', 'egg', 'omelette', 'omelet', 'mayonnaise', 'mayo', 'aioli',
      'quiche', 'flan', 'carbonara', 'meringue', 'crepe', 'brik', 'brick',
      'tiramisu', 'mousse', 'gateau', 'cake', 'brioche', 'gaufre', 'waffle',
      'creme brulee', 'nicoise', 'shakshuka', 'chakchouka', 'ojja',
    ],
    'poisson': [
      'poisson', 'fish', 'saumon', 'salmon', 'thon', 'tuna', 'cabillaud',
      'cod', 'sardine', 'anchois', 'anchovy', 'merlu', 'dorade', 'loup de mer',
      'sole', 'truite', 'trout', 'sushi', 'sashimi', 'maki',
      'nicoise', 'mechouia',
    ],
    'crustaces': [
      'crevette', 'shrimp', 'prawn', 'homard', 'lobster', 'crabe', 'crab',
      'langouste', 'langoustine', 'gambas', 'ecrevisse', 'fruits de mer',
      'seafood', 'paella',
    ],
    'arachides': [
      'cacahuete', 'arachide', 'peanut', 'satay', 'beurre de cacahuete',
    ],
    'fruits a coque': [
      'noix', 'nut', 'walnut', 'amande', 'almond', 'noisette', 'hazelnut',
      'pistache', 'pistachio', 'cajou', 'cashew', 'pecan', 'pignon',
      'praline', 'nutella', 'frangipane', 'makroudh', 'baklava',
    ],
    'soja': ['soja', 'soy', 'tofu', 'miso', 'edamame', 'tempeh'],
    'sesame': ['sesame', 'tahini', 'tahin', 'houmous', 'hummus', 'halva'],
    'moutarde': ['moutarde', 'mustard', 'dijon'],
    'celeri': ['celeri', 'celery'],
  };

  /// Ingredient phrases for the fallback description.
  static const _ingredientPhrases = <String, List<String>>{
    'pâte à pizza': ['pizza'],
    'tomate': ['tomate', 'tomato', 'margherita', 'bolognaise', 'mechouia'],
    'mozzarella': ['mozzarella', 'margherita'],
    'fromage fondant': ['fromage', 'cheese', 'raclette', 'fondue', 'croque'],
    'jambon': ['jambon', 'ham', 'croque'],
    'béchamel': ['bechamel', 'croque', 'lasagne'],
    'pâtes': ['pates', 'pasta', 'spaghetti', 'tagliatelle', 'penne'],
    'poulet': ['poulet', 'chicken'],
    'bœuf': ['boeuf', 'beef', 'steak', 'burger', 'bolognaise'],
    'agneau': ['agneau', 'lamb', 'mechoui'],
    'poisson frais': ['poisson', 'fish', 'dorade', 'loup', 'merlu'],
    'saumon': ['saumon', 'salmon'],
    'thon': ['thon', 'tuna', 'brik'],
    'crevettes': ['crevette', 'shrimp', 'prawn', 'gambas'],
    'œuf': ['oeuf', 'egg', 'omelette', 'brik', 'ojja', 'chakchouka'],
    'semoule et légumes': ['couscous'],
    'légumes mijotés': ['tajine', 'tagine', 'ratatouille'],
    'légumes frais': ['salade', 'salad'],
    'crème': ['creme', 'cream', 'carbonara'],
    'chocolat': ['chocolat', 'chocolate', 'brownie'],
    'fruits': ['fruit', 'pomme', 'apple', 'fraise', 'strawberry', 'citron'],
    'menthe': ['menthe', 'mint'],
  };

  static const _categoryPhrases = <String, String>{
    'Entrée': 'Une entrée préparée à la minute pour ouvrir l\'appétit.',
    'Plat principal': 'Un plat principal préparé à la minute par notre chef.',
    'Dessert': 'Un dessert maison pour finir le repas en douceur.',
    'Boisson': 'Une boisson servie bien fraîche (ou bien chaude).',
    'Snack': 'Un encas gourmand à déguster à toute heure.',
    'Menu enfant': 'Une portion adaptée aux plus petits.',
    'Spécialité': 'Une spécialité de la maison, selon notre recette.',
  };

  static const _dessertKeywords = [
    'gateau', 'cake', 'tarte', 'mousse', 'glace', 'sorbet', 'tiramisu',
    'brownie', 'macaron', 'eclair', 'fondant', 'mille-feuille', 'charlotte',
    'panna cotta', 'cheesecake', 'flan', 'pudding', 'baklava', 'makroudh',
    'creme caramel', 'creme brulee', 'crepe', 'gaufre', 'dessert', 'halwa',
  ];

  static const _drinkKeywords = [
    'jus', 'cafe', 'the a la menthe', 'the vert', 'the noir', 'eau', 'smoothie', 'limonade', 'boisson', 'soda',
    'citronnade', 'milk-shake', 'milkshake', 'juice', 'coffee', 'tea',
    'drink', 'cocktail', 'infusion', 'expresso', 'cappuccino', 'latte',
  ];

  static const _starterKeywords = [
    'soupe', 'salade', 'entree', 'veloute', 'bruschetta', 'carpaccio',
    'tartare', 'tapas', 'mezze', 'houmous', 'brik', 'samoussa', 'lablabi',
    'chorba', 'mechouia',
  ];

  static const _snackKeywords = [
    'sandwich', 'panini', 'wrap', 'toast', 'croissant', 'snack', 'nuggets',
    'croque',
  ];
}

// ─── Enums & DTO ─────────────────────────────────────────────────────────────

enum SuggestionSource { gemini, local }

class DishSuggestion {
  final String description;
  final String category;

  /// Display labels ("Gluten", "Lactose", "Œufs"…), or `['Aucun']`.
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
