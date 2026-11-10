/// Donnees de test du Module 4 (Gaspillage alimentaire) — mode debug seulement.
///
/// Les exemples de l'ancienne base `tablego_module4.db`, rattaches au
/// restaurant de test de TableGo (`resto@test.com`, Le Gourmet) :
///
/// * stock d'ingredients (certains expirent bientot, le lait est perime) ;
/// * journal de gaspillage des 40 derniers jours ;
/// * ventes des 4 dernieres semaines (pour l'IA « quantite a preparer ») ;
/// * deux offres anti-gaspi pour ce soir (`client@test.com` peut les reserver).
///
/// Les dates sont calculees a partir d'aujourd'hui.
/// Ne fait rien si le restaurant a deja des ingredients ou des ventes.
library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../features/gaspillage/outils.dart';

class GaspillageSeed {
  GaspillageSeed._();

  // date d'aujourd'hui + n jours (n negatif = dans le passe)
  static String _jour(int n) {
    return formatDate(aujourdhui().add(Duration(days: n)));
  }

  static Future<void> applyGaspillageDemo(DatabaseExecutor db) async {
    if (!kDebugMode) return;

    List<Map<String, Object?>> resto = await db.rawQuery('''
      SELECT rp.id FROM restaurant_profiles rp
        JOIN users u ON u.id = rp.user_id
       WHERE u.email = ?
    ''', ['resto@test.com']);
    if (resto.isEmpty) return;
    int restaurantId = resto.first['id'] as int;

    List<Map<String, Object?>> dejaStock = await db.query('ingredients',
        where: 'restaurantId = ?', whereArgs: [restaurantId], limit: 1);
    List<Map<String, Object?>> dejaVentes = await db.query('ventes',
        where: 'restaurantId = ?', whereArgs: [restaurantId], limit: 1);
    if (dejaStock.isNotEmpty || dejaVentes.isNotEmpty) return;

    // stock : [nom, quantite, unite, cout, jours avant peremption]
    List<List> stock = [
      ['Tomate', 5, 'kg', 1.8, 2],
      ['Poivron', 3, 'kg', 2.5, 1],
      ['Oeuf', 30, 'pièce', 0.35, 3],
      ['Poulet', 4, 'kg', 11.5, 5],
      ['Lait', 6, 'L', 1.4, -1],
      ['Semoule', 10, 'kg', 1.9, 120],
      ['Pomme de terre', 8, 'kg', 1.2, 10],
      ['Thon', 12, 'pièce', 3.2, 200],
      ['Courgette', 2, 'kg', 1.6, 2],
      ['Fromage', 1.5, 'kg', 24, 6],
    ];
    for (List s in stock) {
      await db.insert('ingredients', {
        'restaurantId': restaurantId,
        'nom': s[0],
        'quantite': s[1],
        'unite': s[2],
        'cout': s[3],
        'datePeremption': _jour(s[4]),
      });
    }

    // journal : [produit, quantite, unite, raison, cout, il y a combien de jours]
    List<List> pertes = [
      ['Pain', 20, 'pièce', 'Surproduction', 4.0, 1],
      ['Couscous', 6, 'pièce', 'Surproduction', 36.0, 2],
      ['Lait', 2, 'L', 'Périmé', 2.8, 4],
      ['Salade verte', 1.5, 'kg', 'Abîmé', 4.5, 6],
      ['Ojja', 2, 'pièce', 'Retour client', 17.0, 9],
      ['Poisson', 1, 'kg', 'Périmé', 28.0, 12],
      ['Lablabi', 5, 'pièce', 'Surproduction', 17.5, 15],
      ['Tomate', 2, 'kg', 'Abîmé', 3.6, 21],
      ['Couscous', 4, 'pièce', 'Surproduction', 24.0, 40],
    ];
    for (List p in pertes) {
      await db.insert('pertes', {
        'restaurantId': restaurantId,
        'produit': p[0],
        'quantite': p[1],
        'unite': p[2],
        'raison': p[3],
        'cout': p[4],
        'date': _jour(-p[5]),
      });
    }

    // ventes des 4 dernieres semaines pour 3 plats
    // (le week-end on vend plus, et on prepare toujours la meme quantite)
    Random r = Random(4);
    List<List> plats = [
      ['Couscous', 30, 18],
      ['Ojja', 20, 12],
      ['Lablabi', 25, 15],
    ];
    for (int n = 28; n >= 1; n--) {
      DateTime d = aujourdhui().subtract(Duration(days: n));
      for (List p in plats) {
        int base = p[2];
        if (d.weekday == 5) base = base + 4; // vendredi
        if (d.weekday >= 6) base = base + 8; // samedi et dimanche
        int vendues = base + r.nextInt(5) - 2;
        if (vendues > p[1]) vendues = p[1];
        await db.insert('ventes', {
          'restaurantId': restaurantId,
          'plat': p[0],
          'preparees': p[1],
          'vendues': vendues,
          'date': formatDate(d),
        });
      }
    }

    // 2 offres anti-gaspi pour ce soir
    await db.insert('offres', {
      'restaurantId': restaurantId,
      'plat': 'Couscous au poulet',
      'prixInitial': 18.0,
      'prixReduit': 10.0,
      'quantite': 6,
      'date': _jour(0),
      'heureFin': '23:00',
    });
    await db.insert('offres', {
      'restaurantId': restaurantId,
      'plat': 'Ojja merguez',
      'prixInitial': 12.0,
      'prixReduit': 7.5,
      'quantite': 4,
      'date': _jour(0),
      'heureFin': '22:30',
    });
    debugPrint('[GaspillageSeed] Module 4 : stock, journal, ventes et offres ajoutes');
  }
}
