# TableGo - Module 4 : Gaspillage alimentaire

Flutter + SQLite (sqflite).

## Lancer
1. `git clone` du projet, puis `git checkout module-gaspillage` et `cd tablego_module4`
2. `flutter pub get`
3. Lancer sur un emulateur Android : `flutter run` (sqflite ne marche pas sur Chrome)
4. Tests : `flutter test`

Le menu (Drawer, bouton en haut a gauche) permet de passer de la vue restaurant a la vue client.
Des donnees de test sont creees au premier lancement (stock, journal, ventes des 4 dernieres semaines, 2 offres pour ce soir).

## Fonctionnalites
- **Ingredients** (restaurant) : stock (nom, quantite, unite, cout, date de peremption) + alertes avant l'expiration
- **Journal de gaspillage** (restaurant) : chaque perte (produit, quantite, raison, cout) + statistiques
- **Offres anti-gaspi** : le restaurant publie des plats a prix reduit en fin de service, le client les reserve avant la fermeture
- **IA** :
  - quantite a preparer chaque jour (moyenne ponderee des ventes du meme jour de la semaine + 10 %)
  - idees de plats avec les ingredients qui expirent dans 3 jours ou moins
  - prix de reduction juste pour les offres de derniere minute

## Fichiers
- `db/database_helper.dart` : base SQLite (tables ingredients, pertes, offres, reservations_offres, ventes + CRUD)
- `models/` : classes Ingredient, Perte, Offre, ReservationOffre, Vente
- `ia/prediction_gaspillage.dart` : IA (quantite a preparer, idees de recettes, prix suggere)
- `api/recettes_api.dart` : API externe TheMealDB (d'autres recettes avec un ingredient, package http)
- `screens/` : les pages
- `widgets/badge_ia.dart` : badge « IA » avec etincelle (charte Figma)
- `widgets/badge_peremption.dart` : etiquette de couleur selon les jours avant peremption
- `session.dart` : utilisateur connecte (a remplacer par le login du module 1)
- `couleurs.dart` : couleurs de la charte Figma
