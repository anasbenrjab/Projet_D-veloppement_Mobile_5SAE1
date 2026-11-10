import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class MealDbException implements Exception {
  const MealDbException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A recipe returned by TheMealDB.
class MealDbRecipe {
  const MealDbRecipe({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.thumbnail,
    required this.ingredients,
    required this.instructions,
  });

  final String id;
  final String name;
  final String category;
  final String area; // cuisine origin, e.g. "Tunisian", "Moroccan"
  final String thumbnail;
  final List<String> ingredients; // "200g Couscous", ...
  final String instructions;

  factory MealDbRecipe.fromJson(Map<String, dynamic> j) {
    final ingredients = <String>[];
    for (var i = 1; i <= 20; i++) {
      final ing = (j['strIngredient$i'] as String?)?.trim() ?? '';
      final measure = (j['strMeasure$i'] as String?)?.trim() ?? '';
      if (ing.isNotEmpty) {
        ingredients.add(measure.isEmpty ? ing : '$measure $ing');
      }
    }
    return MealDbRecipe(
      id: j['idMeal'] as String,
      name: j['strMeal'] as String,
      category: (j['strCategory'] as String?) ?? '',
      area: (j['strArea'] as String?) ?? '',
      thumbnail: (j['strMealThumb'] as String?) ?? '',
      ingredients: ingredients,
      instructions: (j['strInstructions'] as String?) ?? '',
    );
  }

  /// Small preview image (TheMealDB serves /preview thumbnails).
  String get preview => thumbnail.isEmpty ? '' : '$thumbnail/preview';
}

/// External API: TheMealDB (https://www.themealdb.com) — free, no key.
/// Used to find a photo for a dish and to show similar recipes
/// (ingredients) on the dish page.
class MealDbService {
  MealDbService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _base = '/api/json/v1/1';

  /// French dish names → English search terms TheMealDB understands.
  static const _frToEn = {
    'tajine': 'tagine',
    'agneau': 'lamb',
    'poulet': 'chicken',
    'boeuf': 'beef',
    'bœuf': 'beef',
    'poisson': 'fish',
    'thon': 'tuna',
    'crevette': 'prawn',
    'crevettes': 'prawns',
    'salade': 'salad',
    'soupe': 'soup',
    'gâteau': 'cake',
    'gateau': 'cake',
    'brik': 'brik',
    'pâtes': 'pasta',
    'pates': 'pasta',
    'riz': 'rice',
    'œuf': 'egg',
    'oeuf': 'egg',
    'chocolat': 'chocolate',
    'tarte': 'tart',
    'crème': 'cream',
    'pois chiches': 'chickpea',
    'lablabi': 'chickpea',
    'ojja': 'shakshuka',
    'chakchouka': 'shakshuka',
    'makroudh': 'date',
  };

  /// Hosts tried in order (the API answers on both).
  static const _hosts = ['www.themealdb.com', 'themealdb.com'];

  /// One search request, with retry on the backup host and a longer timeout
  /// (the first call can be slow while the CDN warms up).
  Future<List<MealDbRecipe>> _search(String term) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      final host = _hosts[attempt % _hosts.length];
      try {
        final uri = Uri.https(host, '$_base/search.php', {'s': term});
        final res =
            await _client.get(uri).timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) {
          throw MealDbException('HTTP ${res.statusCode}');
        }
        final meals = (jsonDecode(res.body) as Map<String, dynamic>)['meals'];
        if (meals is! List) return [];
        return meals
            .map((m) => MealDbRecipe.fromJson(m as Map<String, dynamic>))
            .toList();
      } catch (e) {
        lastError = e;
        debugPrint('[TheMealDB] "$term" via $host failed (try ${attempt + 1}): $e');
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw MealDbException(_friendly(lastError));
  }

  static String _friendly(Object? e) {
    final s = '$e';
    if (e is TimeoutException) return 'Délai dépassé (réseau lent)';
    if (s.contains('XMLHttpRequest') || s.contains('ClientException')) {
      return 'Requête bloquée par le navigateur ou le réseau '
          '(pare-feu, antivirus ou bloqueur de publicité ?)';
    }
    return s;
  }

  /// Searches with the dish name, then its English translation, then
  /// each meaningful word, until something is found.
  Future<List<MealDbRecipe>> searchForDish(String dishName) async {
    final name = dishName.trim().toLowerCase();
    if (name.isEmpty) return [];

    var translated = name;
    _frToEn.forEach((fr, en) => translated = translated.replaceAll(fr, en));

    final words = translated
        .split(RegExp(r'[\s\-]+'))
        .where((w) => w.length > 3 && !{'avec', 'sauce', 'maison', 'royal'}.contains(w));

    final seen = <String>{};
    final results = <MealDbRecipe>[];
    MealDbException? error;
    var anySucceeded = false;
    for (final term in {name, translated, ...words}) {
      try {
        for (final r in await _search(term)) {
          if (seen.add(r.id)) results.add(r);
        }
        anySucceeded = true;
      } on MealDbException catch (e) {
        error = e; // keep trying the other terms
      }
      if (results.length >= 6) break;
    }
    // Only fail when every request failed (otherwise show what we have).
    if (!anySucceeded && error != null) throw error;
    return results.take(12).toList();
  }
}

final mealDbServiceProvider = Provider((ref) => MealDbService());

/// Similar recipes for a dish name (cached per name by Riverpod).
final similarRecipesProvider =
    FutureProvider.family<List<MealDbRecipe>, String>((ref, dishName) {
  return ref.watch(mealDbServiceProvider).searchForDish(dishName);
});
