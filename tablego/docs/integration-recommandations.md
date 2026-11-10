# Intégration des recommandations (Module 1 ↔ Module 2)

Ce document décrit le **contrat de données** entre le Module 2 (Menu / Commande)
et la fonctionnalité « Recommandé pour vous » / « Plats pour vous » du
Module 1 (Utilisateur).

Le moteur de recommandation est entièrement **local** : aucune API externe,
aucune clé, il fonctionne hors ligne sur web et mobile. Il lit uniquement la
base SQLite de l'application.

## 1. Un seul point de contact : `RecommendationDataSource`

Toutes les lectures de plats, commandes et favoris passent par une seule
classe :

```
lib/features/recommendations/data/recommendation_data_source.dart
```

Si le schéma du Module 2 diffère de ce qui est décrit ici (nom de table,
colonne, format), **seule cette classe doit être adaptée**. Le moteur
(`recommendation_engine.dart`) ne connaît pas la base de données.

Après toute modification, lancer :

```bash
flutter test test/features/recommendations test/core/database
```

## 2. Tables et colonnes lues

| Table                  | Colonnes lues                                                     | Remarque |
|------------------------|-------------------------------------------------------------------|----------|
| `dishes`               | `id`, `restaurant_id`, `name`, `description`, `price`, `photo_path`, `is_available`, `tags`, `allergens` | `restaurant_id` = `restaurant_profiles.id` |
| `order_history`        | `user_id`, `restaurant_id`, `dish_id`, `ordered_at`               | **vue** (v4) sur `orders` + `order_items` du Module 2, lecture seule |
| `favorite_restaurants` | `user_id`, `restaurant_id`, `created_at`                          | géré par le Module 1 |
| `favorite_dishes`      | `user_id`, `dish_id`, `created_at`                                | géré par le Module 1 |
| `client_profiles`      | `user_id`, `dietary_preferences`, `allergies`                     | géré par le Module 1 |
| `restaurant_profiles`  | `id`, `user_id`, `name`, `address`, `cuisine_type`, `photo_paths`, … | géré par le Module 1 |
| `users`                | `id`, `user_type`, `is_active`                                    | seuls les clients actifs comptent |

Depuis la version 4 de la base, `order_history` est une **vue** construite à
partir des tables `orders` et `order_items` du Module 2 (une ligne par plat
commandé, `ordered_at` = date de la commande) : les commandes ne sont stockées
qu'une fois. Pour enregistrer une commande, on écrit dans `orders` /
`order_items` (voir `OrderRepository.placeOrder`), jamais dans la vue.

Les tables `dishes` et `order_history` (v1) sont définies dans
`lib/core/database/tables/shared_tables.dart` (schéma partagé) ; leur logique
métier appartient au Module 2.

## 3. Formats

### Étiquettes de régime (`dishes.tags`)

Tableau JSON de chaînes, **en minuscules, sans accents** :

```json
["halal", "vegetarien"]
```

Valeurs reconnues :

| Valeur        | Signification |
|---------------|---------------|
| `halal`       | plat halal |
| `vegetarien`  | sans viande ni poisson |
| `vegan`       | sans produit animal (compte aussi comme `vegetarien`) |
| `pescetarien` | poisson autorisé, pas de viande |
| `sans gluten` | sans gluten |
| `casher`      | plat casher |

### Allergènes (`dishes.allergens`, depuis la version 3 de la base)

Tableau JSON de chaînes, **en minuscules, sans accents** :

```json
["arachides", "gluten", "lactose"]
```

Valeurs recommandées : `arachides`, `gluten`, `lactose`, `oeufs`, `soja`,
`crustaces`, `fruits a coque`, `poisson`, `sesame`, `moutarde`, `celeri`.

**Important :**

| Valeur de `allergens` | Signification | Effet |
|-----------------------|---------------|-------|
| `["gluten"]`          | contient du gluten | exclu pour un client allergique au gluten |
| `[]`                  | **déclaré** : aucun allergène | proposé à tous |
| `NULL`                | **non renseigné** | **jamais proposé** à un client qui a une allergie (sécurité) |

Il faut donc toujours renseigner `allergens` à la création d'un plat, même
avec `[]`.

### Normalisation

À la lecture, toutes les valeurs sont normalisées (casse, accents, tirets,
synonymes français/anglais) : `"Végétarien"`, `"vegetarian"` et
`"vegetarien"` sont équivalents, `"peanuts"` / `"cacahuètes"` deviennent
`arachides`, `"dairy"` / `"lait"` deviennent `lactose`. Écrire directement la
forme normalisée reste préférable.

### Dates

Format ISO-8601 en UTC, par exemple `2026-11-02T18:30:00Z` (c'est la valeur
par défaut de `ordered_at`). Les commandes récentes comptent davantage
(demi-vie de 30 jours).

## 4. Exigences pour le Module 2

1. **Chaque plat commandé doit être enregistré dans `order_history`**, avec :
   - `user_id` : le client (`users.id`, type `client`) ;
   - `dish_id` : le plat commandé (`dishes.id`) ;
   - `restaurant_id` : le restaurant du plat (`restaurant_profiles.id`) ;
   - `ordered_at` : la date de la commande.

   Une ligne par plat commandé. Sans cela, l'historique de commandes ne
   peut pas être pris en compte.

   ```sql
   INSERT INTO order_history (user_id, restaurant_id, dish_id, ordered_at)
   VALUES (?, ?, ?, strftime('%Y-%m-%dT%H:%M:%SZ','now'));
   ```

2. **Prévenir les recommandations après une commande**, pour qu'elles se
   mettent à jour sans redémarrer l'application :

   ```dart
   import 'package:tablego/core/data/user_data_changes.dart';

   ref.read(userDataChangesProvider.notifier).changed();
   ```

   (Les favoris et le profil le font déjà automatiquement.)

3. **Renseigner `tags` et `allergens`** pour chaque plat, au format ci-dessus.

4. **Préférer `is_available = 0` à la suppression** d'un plat : les plats
   indisponibles ne sont jamais recommandés, mais restent utiles pour
   comprendre les goûts des clients qui les ont commandés.

## 5. Version de la base de données

| Version | Contenu |
|---------|---------|
| v1 | tables initiales (Module 1 + tables partagées) |
| v2 | `profile_photos` (photos web) |
| v3 | `dishes.allergens` (recommandations, Module 1) |
| **v4** | **Module 2 : `dishes.category`, `cart_items`, `orders`, `order_items` ; `order_history` devient une vue** |

La version **4 est prise** (Module 2). Le Module 3 (événements) utilise **v5**.

Règle à suivre pour toute modification de schéma
(`lib/core/database/database_helper.dart`) :

1. écrire un helper idempotent (`CREATE TABLE IF NOT EXISTS`, ou vérifier
   l'existence d'une colonne avec `PRAGMA table_info` avant un
   `ALTER TABLE … ADD COLUMN`) dans le fichier de tables du module ;
2. l'appeler depuis `create()` du module (nouvelles bases) ;
3. incrémenter `_dbVersion` ;
4. l'appeler depuis un bloc `if (oldVersion < N)` dans
   `DatabaseHelper.migrate` (bases existantes) ;
5. ne jamais modifier la définition d'une table déjà livrée.

La base de test (`test/features/auth/helpers/db_test_helper.dart`) utilise
`DatabaseHelper.schemaVersion` et les mêmes `create()`, elle suit donc
automatiquement.
