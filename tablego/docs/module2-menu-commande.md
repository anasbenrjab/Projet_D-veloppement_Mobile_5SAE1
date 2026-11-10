# TableGo — Module 2 : Menu + Commande

Auteur : **Roudaina Saoudi** — Projet Développement Mobile 5SAE1

Intégré dans l'application TableGo (branche `integration`). Ce document décrit
le module tel qu'il fonctionne après intégration ; la version autonome
d'origine est le commit `65c739e` (branche `module-menu-commande`).

## Lancer l'application

```bash
cd tablego
flutter pub get
flutter run -d chrome --dart-define-from-file=secrets.json
```

Connexion avec les comptes de démo (debug, mot de passe `password123`) :

- client : `client@test.com` → **Explorer** → choisir un restaurant → menu,
  panier, commande ; **Activité** = historique des commandes ;
- restaurant : `resto@test.com` → espace restaurant (**Mes plats**,
  **Assistant IA**, **Commandes**, **Mon restaurant**). Le menu tunisien de
  démo du module est rattaché à ce restaurant.

Le choix du rôle (écran d'accueil « Commander / Espace restaurant ») est
remplacé par la connexion du Module Utilisateur : le rôle vient du compte.

## Clé Gemini (assistant IA)

La clé n'est pas dans le code (dépôt public). Copiez `secrets.example.json` en
`tablego/secrets.json` (ignoré par git) et mettez-y votre clé Google AI Studio.

**La clé n'est lue qu'au lancement avec `--dart-define-from-file=secrets.json`**
(`flutter run -d chrome --dart-define-from-file=secrets.json`). Un simple
`flutter run` n'a pas de clé : l'assistant utilise alors ses suggestions
locales. Chaque génération l'indique dans la console :
`[DishAI] path=gemini model=…` ou `[DishAI] path=fallback reason=…`.
Optionnel : `"GEMINI_MODEL": "<nom du modèle>"` dans `secrets.json` pour forcer
un modèle (sinon la liste par défaut est essayée dans l'ordre).

- **Gemini** : le prompt contient le nom du plat (et sa catégorie si le
  restaurant l'a choisie) et demande un JSON `description` (1-2 phrases en
  français, propres au plat), `category`, `allergens` (uniquement la liste
  commune : gluten, lactose, oeufs, poisson, crustaces, arachides,
  fruits a coque, soja, sesame, moutarde, celeri). La réponse est validée
  (valeurs inconnues ignorées, réponse inutilisable → suggestion locale).
- **Suggestion locale** : description construite à partir du nom (ingrédients
  reconnus) et allergènes détectés par mots-clés français et anglais
  (fromage/cheese → lactose, pâtes/pizza/pain → gluten, crevette/shrimp →
  crustacés, œuf/egg → œufs, cacahuète/peanut → arachides, noix/nut → fruits à
  coque…), en mots entiers (« laitue » n'est pas « lait »).

## Fonctionnalités

| Partie | Écran | Détail |
|---|---|---|
| CRUD Plats (restaurant) | Mes plats | Ajouter, modifier, supprimer, disponibilité on/off, photo |
| CRUD Panier (client) | Panier | Ajouter, modifier les quantités, retirer, vider — un panier par client **et par restaurant** |
| CRUD Commandes | Commandes | Client : passer une commande (sur place / à emporter) + historique. Restaurant : statut reçue → en préparation → prête |
| IA | Assistant IA + bouton ✨ du formulaire | Gemini génère description, catégorie et allergènes (+ suggestion locale hors ligne) et des combos |
| API externe | TheMealDB | Recherche de photo pour un plat + « Ailleurs dans le monde » (recettes similaires, ingrédients) sur la fiche plat |

## SQLite (base partagée `tablego.db`, version 4)

Une seule base pour toute l'application (`lib/core/database/database_helper.dart`,
sqflite sur mobile, sqlite3-wasm sur le web). Les tables du module sont dans
`lib/core/database/tables/menu_tables.dart` :

| Table | Rôle |
|---|---|
| `dishes` (partagée) | réutilisée ; le module ajoute `category` (ALTER, v4). Photo → `photo_path`, allergènes → `allergens` (JSON normalisé, ex. `["gluten","lactose"]`) |
| `cart_items` | `user_id` → `users.id`, `dish_id` → `dishes.id` |
| `orders` | `user_id` → `users.id`, `restaurant_id` → `restaurant_profiles.id` |
| `order_items` | `order_id` → `orders.id`, `dish_id` → `dishes.id` (NULL si le plat est supprimé ; nom et prix sont copiés à la commande) |
| `order_history` | **vue** sur `orders` + `order_items`, lue par les recommandations du Module 1 |

## Structure

```
lib/
  core/database/tables/menu_tables.dart     tables du module + vue order_history
  core/database/seeds/menu_seed.dart        menu de démo (photos TheMealDB)
  features/menu/                            plats : modèle, repository, provider, écrans, IA, TheMealDB
  features/commande/                        panier + commandes
  features/commande/presentation/screens/module2_shells.dart
                                            ClientShell (par restaurant) + RestaurantShell
  shared/widgets/                           barre de navigation, image de plat, logo
```
