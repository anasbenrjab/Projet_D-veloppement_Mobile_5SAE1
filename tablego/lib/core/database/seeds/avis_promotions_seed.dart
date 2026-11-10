/// Donnees de test du Module 5 (Avis + Promotions) — mode debug seulement.
///
/// Les exemples de l'ancienne base `tablego_module5.db`, rattaches aux
/// comptes de test de TableGo :
///
/// * restaurant : `resto@test.com` (Le Gourmet) ;
/// * avis : les clients de test karim, sophie, yuki et lucas
///   (`client@test.com` n'a pas encore d'avis : il peut tester « Donner mon
///   avis ») ;
/// * deux promotions : BIENVENUE10 et MALOUF5.
///
/// Ne fait rien si le restaurant a deja des avis ou des promotions.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../features/avis_promotions/ia/analyse_avis.dart';

class AvisPromotionsSeed {
  AvisPromotionsSeed._();

  static Future<void> applyAvisDemo(DatabaseExecutor db) async {
    if (!kDebugMode) return;

    List<Map<String, Object?>> resto = await db.rawQuery('''
      SELECT rp.id FROM restaurant_profiles rp
        JOIN users u ON u.id = rp.user_id
       WHERE u.email = ?
    ''', ['resto@test.com']);
    if (resto.isEmpty) return;
    int restaurantId = resto.first['id'] as int;

    List<Map<String, Object?>> dejaAvis = await db.query('avis',
        where: 'restaurantId = ?', whereArgs: [restaurantId], limit: 1);
    List<Map<String, Object?>> dejaPromos = await db.query('promotions',
        where: 'restaurantId = ?', whereArgs: [restaurantId], limit: 1);
    if (dejaAvis.isNotEmpty || dejaPromos.isNotEmpty) return;

    // [email du client, note, commentaire]
    List<List> exemples = [
      ['karim@test.com', 5, 'Yaatik saha, lablabi behi barcha !'],
      ['sophie@test.com', 4, 'Très bon accueil, un peu d\'attente le samedi.'],
      ['yuki@test.com', 2, 'Déçue, la soupe était froide et le service lent.'],
      ['lucas@test.com', 5, 'Gagnez un iphone gratuit sur www.cadeau.com'],
    ];
    for (List e in exemples) {
      List<Map<String, Object?>> client = await db.rawQuery('''
        SELECT u.id, u.email, cp.full_name FROM users u
          LEFT JOIN client_profiles cp ON cp.user_id = u.id
         WHERE u.email = ?
      ''', [e[0]]);
      if (client.isEmpty) continue;

      String nom = (client.first['full_name'] as String?) ?? e[0];
      await db.insert('avis', {
        'restaurantId': restaurantId,
        'clientId': client.first['id'],
        'clientNom': nom,
        'note': e[1],
        'commentaire': e[2],
        'date': '2026-10-15',
        'sentiment': AnalyseAvis.sentiment(e[2], e[1]),
        'spam': AnalyseAvis.estSpam(e[2]) ? 1 : 0,
      });
    }

    await db.insert('promotions', {
      'restaurantId': restaurantId,
      'titre': 'Bienvenue',
      'type': '%',
      'valeur': 10,
      'code': 'BIENVENUE10',
      'dateFin': '2026-12-31',
      'actif': 1,
    });
    await db.insert('promotions', {
      'restaurantId': restaurantId,
      'titre': 'Soirée malouf',
      'type': 'TND',
      'valeur': 5,
      'code': 'MALOUF5',
      'dateFin': '2026-11-30',
      'actif': 1,
    });
    debugPrint('[AvisPromotionsSeed] Module 5 : avis et promotions ajoutes');
  }
}
