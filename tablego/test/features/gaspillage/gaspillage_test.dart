// Module 4 (gaspillage alimentaire) sur la base commune de TableGo :
// IA, CRUD ingredients / pertes / offres, reservations, cles etrangeres
// et donnees de test.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tablego/core/database/database_helper.dart';
import 'package:tablego/core/database/seeds/gaspillage_seed.dart';
import 'package:tablego/features/gaspillage/db/gaspillage_db.dart';
import 'package:tablego/features/gaspillage/ia/prediction_gaspillage.dart';
import 'package:tablego/features/gaspillage/models/ingredient.dart';
import 'package:tablego/features/gaspillage/models/offre.dart';
import 'package:tablego/features/gaspillage/models/perte.dart';
import 'package:tablego/features/gaspillage/models/reservation_offre.dart';
import 'package:tablego/features/gaspillage/models/vente.dart';
import 'package:tablego/features/gaspillage/outils.dart';

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

String dansJours(int n) => formatDate(aujourdhui().add(Duration(days: n)));

Ingredient ingredient(String nom, int jours) => Ingredient(
      restaurantId: restaurantId,
      nom: nom,
      quantite: 2,
      unite: 'kg',
      cout: 3,
      datePeremption: dansJours(jours),
    );

Offre offreDe(int portions) => Offre(
      restaurantId: restaurantId,
      plat: 'Couscous',
      prixInitial: 18,
      prixReduit: 10,
      quantite: portions,
      date: dansJours(1), // demain : toujours disponible pendant le test
      heureFin: '23:00',
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await (await buildTestDb()).database;
    // GaspillageDb utilise DatabaseHelper.instance
    DatabaseHelper.useDatabaseForTesting(db);
    clientId = await creerUser('client@m4.test', 'client');
    int owner = await creerUser('resto@m4.test', 'restaurant');
    restaurantId = await db.insert(
        'restaurant_profiles', {'user_id': owner, 'name': 'Le Gourmet'});
  });

  tearDown(() => DatabaseHelper.useDatabaseForTesting(null));

  group('IA du gaspillage', () {
    test('prix suggere : -30 % de base, arrondi au 0,5', () {
      PrixSuggere s = PredictionGaspillage.prixSuggere(20, 300, 2);
      expect(s.pourcentage, 30);
      expect(s.prix, 14);
    });

    test('quantite a preparer : moyenne du meme jour + 10 %', () {
      DateTime lundi = DateTime(2026, 11, 9);
      List<Vente> ventes = [
        for (int s = 1; s <= 4; s++)
          Vente(
            restaurantId: restaurantId,
            plat: 'Couscous',
            preparees: 30,
            vendues: 20,
            date: formatDate(lundi.subtract(Duration(days: 7 * s))),
          ),
      ];
      Prediction p =
          PredictionGaspillage.quantiteAPreparer(ventes, 'Couscous', lundi);
      expect(p.quantite, 22);
      expect(p.economie(), 8);
    });

    test('idees : ingredient urgent oui, ingredient perime non', () {
      expect(PredictionGaspillage.idees([ingredient('Tomates', 1)]).first.urgents,
          ['Tomates']);
      expect(PredictionGaspillage.idees([ingredient('Lait', -1)]), isEmpty);
    });
  });

  group('CRUD', () {
    test('ingredients : ajouter, lire, modifier, supprimer', () async {
      GaspillageDb g = GaspillageDb();
      int id = await g.insertIngredient(ingredient('Tomate', 5));

      List<Ingredient> stock = await g.getIngredients(restaurantId);
      expect(stock.length, 1);

      stock.first.quantite = 7;
      await g.updateIngredient(stock.first);
      expect((await g.getIngredients(restaurantId)).first.quantite, 7);

      await g.deleteIngredient(id);
      expect(await g.getIngredients(restaurantId), isEmpty);
    });

    test('jeter un ingredient : il passe dans le journal', () async {
      GaspillageDb g = GaspillageDb();
      await g.insertIngredient(ingredient('Lait', -1));
      Ingredient lait = (await g.getIngredients(restaurantId)).first;

      await g.jeterIngredient(lait, 'Périmé');

      expect(await g.getIngredients(restaurantId), isEmpty);
      List<Perte> pertes = await g.getPertes(restaurantId);
      expect(pertes.single.produit, 'Lait');
      expect(pertes.single.cout, 6); // 2 kg x 3 TND
    });

    test('reserver puis annuler rend les portions', () async {
      GaspillageDb g = GaspillageDb();
      await g.insertOffre(offreDe(3));
      Offre o = (await g.getOffres(restaurantId)).first;

      expect(await g.reserverOffre(o, 2, clientId, 'Alice'), isTrue);
      expect(await g.reserverOffre(o, 2, clientId, 'Alice'), isFalse);
      expect((await g.getOffres(restaurantId)).first.quantite, 1);
      expect((await g.getPortionsReservees(restaurantId))[o.id], 2);

      List<ReservationOffre> mes =
          await g.getReservationsClient(clientId, restaurantId);
      expect(mes.single.plat, 'Couscous');

      await g.annulerReservation(mes.single);
      expect((await g.getOffres(restaurantId)).first.quantite, 3);
    });

    test('supprimer le restaurant supprime ses donnees (cascade)', () async {
      GaspillageDb g = GaspillageDb();
      await g.insertIngredient(ingredient('Tomate', 5));
      await g.insertOffre(offreDe(3));
      await db.delete('restaurant_profiles',
          where: 'id = ?', whereArgs: [restaurantId]);
      expect(await g.getIngredients(restaurantId), isEmpty);
      expect(await g.getOffres(restaurantId), isEmpty);
    });
  });

  test('donnees de test : rien sans le restaurant resto@test.com', () async {
    await GaspillageSeed.applyGaspillageDemo(db);
    expect(await GaspillageDb().getIngredients(restaurantId), isEmpty);
  });
}
