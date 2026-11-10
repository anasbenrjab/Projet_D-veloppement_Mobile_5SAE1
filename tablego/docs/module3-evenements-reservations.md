# TableGo — Module 3 : Événements & Réservations

Intégré dans l'application TableGo (branche `integration`). La version
autonome d'origine est le commit `553e67a` (branche `module-resto-events`,
dossier `Desktop/app mobile/`).

## Où le trouver dans l'application

Comptes de démo (debug, mot de passe `password123`) :

- **restaurant** `resto@test.com` → onglet **Réservations** de l'espace
  restaurant : *Demandes* (accepter / refuser, score de no-show),
  *Affluence IA* (créneaux chargés + météo Open-Meteo), *Événements* (CRUD).
- **client** `client@test.com` → **Explorer** → un restaurant → onglet
  **Réserver** : événements à venir du restaurant (lecture seule), ses
  réservations dans ce restaurant et le bouton « Réserver » (score de no-show
  et créneaux alternatifs proposés par l'IA si le créneau est complet).
  **Activité → Réservations** : toutes ses réservations.

Les données de démo du module (320 réservations passées, 10 à venir dont un
samedi presque complet, 3 événements) sont rattachées à `resto@test.com`.

## Fonctionnalités (inchangées)

| Partie | Détail |
|---|---|
| CRUD Réservations | client : créer, modifier, annuler ; restaurant : accepter, refuser, honorée / no-show |
| CRUD Événements | restaurant : créer, lister, modifier, supprimer (anniversaire, soirée, musique live) |
| IA locale | 1. prédiction d'affluence (SQL `strftime`) ; 2. score de risque de no-show ; 3. créneaux alternatifs |
| API externe | Open-Meteo (météo actuelle, sans clé) |

## Intégration : ce qui a changé

| Avant (application autonome) | Après (TableGo) |
|---|---|
| base `resto_events.db` et son `DatabaseHelper` | base partagée `tablego.db` ; `database/evenements_repository.dart` garde les mêmes méthodes et requêtes |
| tables `restaurant`, `client`, `meta` | `restaurant_profiles` (capacité = `seat_capacity`, 40 par défaut), `users` + `client_profiles` (nom du client) ; plus de table `meta` |
| un seul restaurant (`id = 1`) | le restaurant du compte connecté (écrans restaurant) ou celui choisi par le client |
| choix du rôle puis d'un profil client fictif | connexion du Module Utilisateur (`authProvider`) |
| données de démo recréées (tables vidées) à chaque version | seed idempotent, en debug seulement (`core/database/seeds/events_seed.dart`) |

Schéma : `lib/core/database/tables/events_tables.dart` (version 5 de la base).

## Règles de sécurité dans le repository (ajoutées à l'intégration)

Les écrans respectaient déjà ces règles (statuts fixés par les boutons,
places restantes recalculées et bornées par le formulaire d'événement) ;
`EvenementsRepository` les vérifie maintenant aussi. Une donnée refusée lève
une `ValidationException` (`lib/core/data/validation_exception.dart`) dont le
message français s'affiche tel quel dans les SnackBar « Erreur : … » ; rien
n'est écrit en base.

| Méthode | Règle | Message |
|---|---|---|
| `insererReservation`, `modifierReservation`, `changerStatutReservation` | statut parmi `Reservation.statuts` : en_attente, acceptee, refusee, annulee, honoree, no_show | « Statut de réservation invalide : « … ». » |
| `insererEvenement`, `modifierEvenement` | 0 ≤ places restantes ≤ places totales | « Places restantes invalides : elles doivent être entre 0 et le nombre total de places. » |

`Reservation.statuts` est une nouvelle constante du modèle qui regroupe les
six statuts existants (aucune valeur n'a changé).

Tests : `test/repositories/evenements_repository_crud_test.dart` (groupe
« safety rules »).

## Structure

```
lib/features/events/
  database/evenements_repository.dart   accès aux données (ancien DatabaseHelper)
  models/                               evenement, reservation, restaurant, meteo, resultats_ia
  services/                             ai_service (IA locale), service_meteo (Open-Meteo)
  screens/module3_entrees.dart          points d'entrée dans la navigation TableGo
  screens/client/                       mes réservations, formulaire de réservation
  screens/restaurant/                   accueil, demandes, affluence, événements
  utils/, widgets/
```
