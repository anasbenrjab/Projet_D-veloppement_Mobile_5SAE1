# TableGo — Module 2 : Menu + Commande

Auteur : **Roudaina Saoudi** — Projet Développement Mobile 5SAE1

## Lancer l'application

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=secrets.json
```

Sur l'écran d'accueil, choisissez **Commander (client)** ou **Espace restaurant**.
(On passe d'un espace à l'autre avec l'icône boutique en haut de l'accueil client,
ou l'onglet « Vue client » côté restaurant.)

## Clé Gemini (assistant IA)

La clé n'est pas dans le code (dépôt public). Copiez `secrets.example.json` en
`secrets.json` (ignoré par git) et mettez-y votre clé Google AI Studio.
Sans clé, l'assistant utilise ses suggestions locales.

## Fonctionnalités

| Partie | Écran | Détail |
|---|---|---|
| CRUD Plats (restaurant) | Mes plats | Ajouter, modifier, supprimer, disponibilité on/off, photo |
| CRUD Panier (client) | Panier | Ajouter, modifier les quantités, retirer, vider |
| CRUD Commandes | Commandes | Client : passer une commande (sur place / à emporter) + historique. Restaurant : statut reçue → en préparation → prête |
| IA | Assistant IA + bouton ✨ du formulaire | Gemini génère description, catégorie et allergènes (+ suggestion locale hors ligne) et des combos |
| API externe | TheMealDB | Recherche de photo pour un plat + « Ailleurs dans le monde » (recettes similaires, ingrédients) sur la fiche plat |

## SQLite

- Android / iOS : `sqflite` (base `tablego_module2.db`)
- Windows / Linux / macOS : `sqflite_common_ffi`
- Web (Chrome) : `InMemoryStore`, même interface CRUD, sauvegardé dans le
  localStorage pour survivre au rechargement de la page.

Tables : `dishes`, `cart_items`, `orders`, `order_items` (voir `lib/core/database/database_helper.dart`).

## Structure

```
lib/
  main.dart                     écran d'accueil + ClientShell + RestaurantShell (une seule barre de navigation)
  app/navigation.dart           onglets actifs (Riverpod)
  core/database/                SQLite + store web + données de démo
  features/menu/                plats : modèle, repository, provider, écrans, IA, TheMealDB
  features/commande/            panier + commandes
  shared/widgets/               barre de navigation, image de plat, logo, boutons
```
