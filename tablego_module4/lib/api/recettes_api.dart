import 'dart:convert';
import 'package:http/http.dart' as http;

// API externe gratuite (TheMealDB) : des recettes avec un ingredient
// exemple : https://www.themealdb.com/api/json/v1/1/filter.php?i=chicken
// reponse JSON : {"meals": [{"strMeal": "...", "strMealThumb": "...", "idMeal": "..."}]}
// si aucun resultat : {"meals": null}
class RecettesApi {
  // l'API est en anglais : petit dictionnaire francais -> anglais
  static Map<String, String> traductions = {
    'tomate': 'tomato',
    'poivron': 'pepper',
    'oeuf': 'egg',
    'poulet': 'chicken',
    'lait': 'milk',
    'semoule': 'couscous',
    'pomme de terre': 'potatoes',
    'thon': 'tuna',
    'courgette': 'zucchini',
    'fromage': 'cheese',
    'oignon': 'onion',
    'ail': 'garlic',
    'carotte': 'carrot',
    'riz': 'rice',
    'boeuf': 'beef',
    'agneau': 'lamb',
    'poisson': 'salmon',
    'crevette': 'prawns',
    'citron': 'lemon',
    'beurre': 'butter',
    'creme': 'cream',
    'champignon': 'mushrooms',
    'aubergine': 'aubergine',
    'pois chiche': 'chickpeas',
  };

  // retourne null si on ne connait pas la traduction
  static String? traduire(String nomNettoye) {
    for (String fr in traductions.keys) {
      if (nomNettoye.contains(fr)) return traductions[fr];
    }
    return null;
  }

  // liste de recettes : chaque recette = {'nom': ..., 'photo': ...}
  static Future<List<Map<String, String>>> chercher(String ingredientEn) async {
    String url = 'https://www.themealdb.com/api/json/v1/1/filter.php'
        '?i=${Uri.encodeComponent(ingredientEn)}';

    http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Erreur ${response.statusCode}');
    }

    Map<String, dynamic> data = json.decode(response.body);
    if (data['meals'] == null) return [];

    List<Map<String, String>> res = [];
    for (var m in data['meals']) {
      res.add({'nom': m['strMeal'], 'photo': m['strMealThumb']});
      if (res.length == 10) break; // 10 idees suffisent
    }
    return res;
  }
}
