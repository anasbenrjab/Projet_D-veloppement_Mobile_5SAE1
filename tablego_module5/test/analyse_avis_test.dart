import 'package:flutter_test/flutter_test.dart';
import 'package:tablego_module5/ia/analyse_avis.dart';
import 'package:tablego_module5/models/promotion.dart';
import 'package:tablego_module5/outils.dart';

void main() {
  // ---------------- SENTIMENT ----------------

  test('avis positif', () {
    expect(AnalyseAvis.sentiment('Le couscous est délicieux', 5), 'positif');
  });

  test('avis negatif', () {
    expect(AnalyseAvis.sentiment('Déçue, la ojja était froide', 1), 'negatif');
  });

  test('negation : pas bon', () {
    expect(AnalyseAvis.sentiment("Ce n'est pas bon", 3), 'negatif');
  });

  test("negation apres le mot : j'aime pas", () {
    expect(AnalyseAvis.sentiment("J'aime pas", 3), 'negatif');
  });

  test('bon, pas cher -> positif', () {
    expect(AnalyseAvis.sentiment("C'est bon, pas cher", 3), 'positif');
  });

  test('avis neutre', () {
    expect(AnalyseAvis.sentiment('Correct, sans plus.', 3), 'neutre');
  });

  // ---------------- SPAM ----------------

  test('spam avec un lien', () {
    expect(AnalyseAvis.estSpam('Visitez www.cadeau.com'), true);
  });

  test('spam avec un numero', () {
    expect(AnalyseAvis.estSpam('Appelez le 22 123 456'), true);
  });

  test('spam avec mots de pub', () {
    expect(AnalyseAvis.estSpam('Gagnez un repas gratuit'), true);
  });

  test('avis normal pas spam', () {
    expect(AnalyseAvis.estSpam('Très bon accueil, merci'), false);
  });

  // ---------------- MOTS OFFENSANTS ----------------

  test('mot offensant', () {
    expect(AnalyseAvis.estOffensant('Service de merde'), true);
  });

  test('pas offensant', () {
    expect(AnalyseAvis.estOffensant('Service lent'), false);
  });

  // ---------------- PROMOTION ----------------

  test('reduction en pourcentage', () {
    Promotion p = Promotion(
        restaurantId: 1, titre: 'Test', type: '%', valeur: 10,
        code: 'TEST10', dateFin: '2030-12-31');
    expect(p.calculerReduction(50), 5);
  });

  test('reduction en TND pas plus que le montant', () {
    Promotion p = Promotion(
        restaurantId: 1, titre: 'Test', type: 'TND', valeur: 20,
        code: 'TEST20', dateFin: '2030-12-31');
    expect(p.calculerReduction(15), 15);
  });

  test('promotion expiree', () {
    Promotion p = Promotion(
        restaurantId: 1, titre: 'Test', type: '%', valeur: 10,
        code: 'VIEUX', dateFin: '2020-01-01');
    expect(p.estExpiree(), true);
  });

  // ---------------- OUTILS ----------------

  test('affichage des nombres', () {
    expect(nombre(10), '10');
    expect(nombre(2.5), '2,5');
    expect(virgule(4.8, 1), '4,8');
    expect(virgule(54, 3), '54,000');
  });

  test('date en francais', () {
    expect(dateFr('2026-10-15'), '15/10/2026');
  });
}
