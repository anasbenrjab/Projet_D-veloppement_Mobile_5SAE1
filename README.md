# TableGo - Module 5 : Avis + Promotions

Flutter + SQLite (sqflite).

## Lancer
1. `git clone` du projet
2. `flutter pub get`
3. Lancer sur un emulateur Android : `flutter run` (sqflite ne marche pas sur Chrome)
4. Tests : `flutter test`

Le menu (Drawer, bouton en haut a gauche) permet de passer de la vue client a la vue restaurant.
Codes promo pour tester : BIENVENUE10, MALOUF5

## Fichiers
- `db/database_helper.dart` : base SQLite (tables avis et promotions + CRUD)
- `models/` : classes Avis et Promotion
- `ia/analyse_avis.dart` : IA (sentiment + spam + mots offensants)
- `api/traduction_api.dart` : API externe MyMemory (traduction des avis en anglais, package http)
- `screens/` : les pages
- `widgets/badge_ia.dart` : badge « IA » avec étincelle (charte Figma)
- `session.dart` : utilisateur connecte (a remplacer par le login du module 1)
- `couleurs.dart` : couleurs de la charte Figma
