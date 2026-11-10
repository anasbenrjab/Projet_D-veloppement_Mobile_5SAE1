// Module 5 (avis + promotions) sur la base commune de TableGo :
// IA des avis, CRUD avis / promotions, cles etrangeres et donnees de test.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/seeds/avis_promotions_seed.dart';
import 'package:tablego/features/avis_promotions/db/avis_promotions_db.dart';
import 'package:tablego/features/avis_promotions/ia/analyse_avis.dart';
import 'package:tablego/features/avis_promotions/models/avis.dart';
import 'package:tablego/features/avis_promotions/models/promotion.dart';

import '../auth/helpers/db_test_helper.dart';

late Database db;
late int clientId, restaurantId;

Future<int> creerUser(String email, String type) => db.insert('users', {
      'email': email,
      'password_hash': 'h',
      'salt': 's',
      'password_iterations': 1,
      'user_type': type,
    });

Avis avisDe(int client, int note, String texte) => Avis(
      restaurantId: restaurantId,
      clientId: client,
      clientNom: 'Alice',
      note: note,
      commentaire: texte,
      date: '2026-11-10',
      sentiment: AnalyseAvis.sentiment(texte, note),
      spam: AnalyseAvis.estSpam(texte) ? 1 : 0,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await (await buildTestDb()).database;
    // AvisPromotionsDb utilise DatabaseHelper.instance
    DatabaseHelper.useDatabaseForTesting(db);
    clientId = await creerUser('client@m5.test', 'client');
    int owner = await creerUser('resto@m5.test', 'restaurant');
    restaurantId = await db.insert(
        'restaurant_profiles', {'user_id': owner, 'name': 'Le Gourmet'});
  });

  tearDown(() => DatabaseHelper.useDatabaseForTesting(null));

  group('IA des avis', () {
    test('sentiment positif, negatif, et negation', () {
      expect(AnalyseAvis.sentiment('Excellent, très bon service', 5), 'positif');
      expect(AnalyseAvis.sentiment('Froid et lent, déçue', 1), 'negatif');
      expect(AnalyseAvis.sentiment("Ce n'est pas bon", 3), 'negatif');
    });

    test('spam : lien, telephone, mots de pub', () {
      expect(AnalyseAvis.estSpam('Gagnez sur www.cadeau.com'), isTrue);
      expect(AnalyseAvis.estSpam('Appelez le 22 333 444'), isTrue);
      expect(AnalyseAvis.estSpam('Bon repas, merci'), isFalse);
    });

    test('mots offensants', () {
      expect(AnalyseAvis.estOffensant('Service de merde'), isTrue);
      expect(AnalyseAvis.estOffensant('Service rapide'), isFalse);
    });
  });

  group('CRUD avis', () {
    test('ajouter, lire, modifier, repondre, supprimer', () async {
      AvisPromotionsDb dbAvis = AvisPromotionsDb();
      int id = await dbAvis.insertAvis(avisDe(clientId, 5, 'Super couscous'));

      List<Avis> liste = await dbAvis.getAvis(restaurantId);
      expect(liste.length, 1);
      expect(liste.first.sentiment, 'positif');

      Avis a = liste.first;
      a.note = 2;
      a.commentaire = 'Plat froid';
      await dbAvis.updateAvis(a);
      await dbAvis.repondre(id, 'Désolé, merci pour votre retour');
      a = (await dbAvis.getAvis(restaurantId)).first;
      expect(a.note, 2);
      expect(a.reponse, 'Désolé, merci pour votre retour');

      await dbAvis.deleteAvis(id);
      expect(await dbAvis.getAvis(restaurantId), isEmpty);
    });

    test('un seul avis par client et par restaurant', () async {
      AvisPromotionsDb dbAvis = AvisPromotionsDb();
      await dbAvis.insertAvis(avisDe(clientId, 5, 'Très bon'));
      expect(() => dbAvis.insertAvis(avisDe(clientId, 4, 'Encore')),
          throwsA(isA<DatabaseException>()));
    });

    test("un avis d'un client qui n'existe pas est refuse (cle etrangere)",
        () async {
      expect(() => AvisPromotionsDb().insertAvis(avisDe(9999, 5, 'Bon')),
          throwsA(isA<DatabaseException>()));
    });

    test("l'avis est supprime avec le compte du client", () async {
      await AvisPromotionsDb().insertAvis(avisDe(clientId, 5, 'Très bon'));
      await db.delete('users', where: 'id = ?', whereArgs: [clientId]);
      expect(await AvisPromotionsDb().getAvis(restaurantId), isEmpty);
    });
  });

  group('CRUD promotions', () {
    test('ajouter, chercher par code, modifier, supprimer', () async {
      AvisPromotionsDb dbPromo = AvisPromotionsDb();
      int id = await dbPromo.insertPromotion(Promotion(
        restaurantId: restaurantId,
        titre: 'Bienvenue',
        type: '%',
        valeur: 10,
        code: 'BIENVENUE10',
        dateFin: '2099-12-31',
      ));

      Promotion? p = await dbPromo.getPromotionParCode('bienvenue10');
      expect(p, isNotNull);
      expect(p!.calculerReduction(50), 5);

      p.actif = 0;
      await dbPromo.updatePromotion(p);
      p = await dbPromo.getPromotionParCode('BIENVENUE10');
      expect(p!.actif, 0);

      await dbPromo.deletePromotion(id);
      expect(await dbPromo.getPromotions(restaurantId), isEmpty);
    });

    test('reduction en TND et promotion expiree', () {
      Promotion p = Promotion(
        restaurantId: 1,
        titre: 'Soirée',
        type: 'TND',
        valeur: 5,
        code: 'MALOUF5',
        dateFin: '2020-01-01',
      );
      expect(p.calculerReduction(30), 5);
      expect(p.calculerReduction(3), 3); // jamais plus que le montant
      expect(p.estExpiree(), isTrue);
    });
  });

  test('donnees de test : rattachees aux comptes de test, une seule fois',
      () async {
    // les comptes de test utilises par le seed
    int resto = await creerUser('resto@test.com', 'restaurant');
    int gourmet = await db.insert(
        'restaurant_profiles', {'user_id': resto, 'name': 'Le Gourmet'});
    int karim = await creerUser('karim@test.com', 'client');
    await db.insert(
        'client_profiles', {'user_id': karim, 'full_name': 'Karim Benali'});
    await creerUser('lucas@test.com', 'client');

    await AvisPromotionsSeed.applyAvisDemo(db);
    await AvisPromotionsSeed.applyAvisDemo(db); // ne double pas

    List<Avis> avis = await AvisPromotionsDb().getAvis(gourmet);
    expect(avis.length, 2); // seulement karim et lucas existent ici
    Avis deKarim = avis.firstWhere((a) => a.clientId == karim);
    expect(deKarim.clientNom, 'Karim Benali');
    expect(avis.where((a) => a.spam == 1).length, 1); // l'avis de lucas
    expect((await AvisPromotionsDb().getPromotions(gourmet)).length, 2);
  });
}
