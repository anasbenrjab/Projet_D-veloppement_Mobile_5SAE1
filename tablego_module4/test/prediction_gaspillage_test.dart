import 'package:flutter_test/flutter_test.dart';
import 'package:tablego_module4/ia/prediction_gaspillage.dart';
import 'package:tablego_module4/models/ingredient.dart';
import 'package:tablego_module4/models/vente.dart';
import 'package:tablego_module4/outils.dart';

// tests de l'IA du module 4 (pas besoin de telephone)
void main() {
  test('prix suggere : -30 % de base, arrondi au 0,5', () {
    PrixSuggere s = PredictionGaspillage.prixSuggere(20, 300, 2);
    expect(s.pourcentage, 30);
    expect(s.prix, 14);
  });

  test('prix suggere : jamais plus de -60 %', () {
    PrixSuggere s = PredictionGaspillage.prixSuggere(20, 30, 15);
    expect(s.pourcentage, 55);
    expect(s.prix <= 20 * 0.5, true);
  });

  test('quantite a preparer : moyenne du meme jour + 10 %', () {
    DateTime lundi = DateTime(2026, 11, 9); // un lundi
    List<Vente> ventes = [];
    for (int s = 1; s <= 4; s++) {
      ventes.add(Vente(
        restaurantId: 1,
        plat: 'Couscous',
        preparees: 30,
        vendues: 20,
        date: formatDate(lundi.subtract(Duration(days: 7 * s))),
      ));
    }
    Prediction p =
        PredictionGaspillage.quantiteAPreparer(ventes, 'Couscous', lundi);
    expect(p.quantite, 22); // 20 * 1.1
    expect(p.economie(), 8); // 30 - 22
  });

  test('idees : une recette avec un ingredient qui expire bientot', () {
    List<Ingredient> stock = [
      Ingredient(
        restaurantId: 1,
        nom: 'Tomates',
        quantite: 3,
        unite: 'kg',
        cout: 2,
        datePeremption: formatDate(aujourdhui().add(const Duration(days: 1))),
      ),
    ];
    List<IdeeRecette> idees = PredictionGaspillage.idees(stock);
    expect(idees.isNotEmpty, true);
    expect(idees.first.urgents, ['Tomates']);
  });

  test('un ingredient perime n est pas propose', () {
    List<Ingredient> stock = [
      Ingredient(
        restaurantId: 1,
        nom: 'Lait',
        quantite: 2,
        unite: 'L',
        cout: 1.4,
        datePeremption: formatDate(aujourdhui().subtract(const Duration(days: 1))),
      ),
    ];
    expect(PredictionGaspillage.idees(stock).isEmpty, true);
  });
}
