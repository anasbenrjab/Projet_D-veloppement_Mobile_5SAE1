import '../database/database_helper.dart';
import '../models/resultats_ia.dart';
import '../utils/aide_dates.dart';

/// Service d'intelligence artificielle 100 % LOCAL.
///
/// Aucune API externe : tout repose sur des requêtes SQL sur l'historique
/// des réservations et des calculs simples en Dart. Les trois fonctions :
///
///   1. [predireAffluence]         -> prédire les heures chargées de la semaine ;
///   2. [calculerScoreNoShow]      -> noter le risque qu'un client ne vienne pas ;
///   3. [proposerCreneauxAlternatifs] -> suggérer d'autres heures si c'est complet.
class AiService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ---------------------------------------------------------------------------
  // 1) PRÉDICTION DES HEURES D'AFFLUENCE
  // ---------------------------------------------------------------------------

  /// Analyse l'historique des réservations (acceptées, honorées et no-show)
  /// et renvoie la moyenne de personnes présentes pour chaque créneau
  /// récurrent "jour de la semaine + heure".
  ///
  /// Un créneau est marqué "chargé" quand la moyenne dépasse 80 % de la
  /// capacité maximale du restaurant (ex. 80 % de 40 = 32 personnes).
  Future<List<CreneauAffluence>> predireAffluence() async {
    final restaurant = await _db.restaurantPrincipal();
    final seuilChargement = restaurant.capaciteMax * 0.8;

    final lignes = await _db.affluenceParCreneau();
    final resultats = <CreneauAffluence>[];
    for (final ligne in lignes) {
      // strftime('%w') renvoie du texte : "0" (dimanche) à "6" (samedi).
      final jourIndex = int.parse(ligne['jour'].toString());
      final moyenne = ((ligne['moyenne'] as num?) ?? 0).toDouble();
      resultats.add(CreneauAffluence(
        jourIndex: jourIndex,
        jourNom: AideDates.nomsJours[jourIndex],
        heure: ligne['heure'].toString(),
        moyennePersonnes: moyenne,
        charge: moyenne > seuilChargement,
      ));
    }
    // Les créneaux les plus fréquentés apparaissent en premier.
    resultats.sort((a, b) => b.moyennePersonnes.compareTo(a.moyennePersonnes));
    return resultats;
  }

  // ---------------------------------------------------------------------------
  // 2) SCORE DE RISQUE DE NO-SHOW
  // ---------------------------------------------------------------------------

  /// Calcule, pour une nouvelle réservation, la probabilité (0 à 1) que le
  /// client ne se présente pas.
  ///
  /// Barème :
  ///   - base ......................... 0.10
  ///   - le client a déjà fait un no-show : +0.40
  ///   - réservation prise plus de 7 jours à l'avance : +0.20
  ///   - groupe de plus de 6 personnes : +0.10
  ///   - réservation déjà modifiée 2 fois ou plus : +0.10
  ///
  /// Le résultat est plafonné à 1.
  Future<double> calculerScoreNoShow({
    required int clientId,
    required String date,
    required int nbPersonnes,
    required int nbModifications,
  }) async {
    // L'historique du client vient de la base : a-t-il déjà manqué une résa ?
    final nbNoShows = await _db.compterNoShows(clientId);
    return formuleScoreNoShow(
      aDejaNoShow: nbNoShows > 0,
      joursDavance: AideDates.joursDavance(date),
      nbPersonnes: nbPersonnes,
      nbModifications: nbModifications,
    );
  }

  /// La formule elle-même, sans accès à la base : elle est "pure", ce qui
  /// permet de la réutiliser pour les données de démo et pour les tests.
  static double formuleScoreNoShow({
    required bool aDejaNoShow,
    required int joursDavance,
    required int nbPersonnes,
    required int nbModifications,
  }) {
    double score = 0.10; // base : tout le monde peut ne pas venir
    if (aDejaNoShow) score += 0.40;
    if (joursDavance > 7) score += 0.20;
    if (nbPersonnes > 6) score += 0.10;
    if (nbModifications >= 2) score += 0.10;
    if (score > 1.0) score = 1.0; // plafond
    return score;
  }

  // ---------------------------------------------------------------------------
  // 3) CRÉNEAUX ALTERNATIFS
  // ---------------------------------------------------------------------------

  /// Un créneau est complet quand la somme des personnes déjà acceptées,
  /// plus la nouvelle demande, dépasse la capacité maximale du créneau.
  Future<bool> creneauComplet({
    required String date,
    required String heure,
    required int nbPersonnes,
  }) async {
    final restaurant = await _db.restaurantPrincipal();
    final dejaPrises = await _db.sommePersonnesAcceptees(date, heure);
    return dejaPrises + nbPersonnes > restaurant.capaciteMax;
  }

  /// Si le créneau demandé est complet, teste les heures voisines le même
  /// jour (±1h, ±2h, ±3h) et renvoie les 3 meilleures propositions.
  ///
  /// Classement : d'abord les créneaux les plus PROCHES de la demande,
  /// et en cas d'égalité ceux dont l'affluence PRÉDITE est la plus basse.
  Future<List<CreneauPropose>> proposerCreneauxAlternatifs({
    required String date,
    required String heure,
    required int nbPersonnes,
  }) async {
    final restaurant = await _db.restaurantPrincipal();

    // Affluence prédite par créneau récurrent : sert à départager les
    // égalités en évitant les heures déjà réputées chargées.
    final affluences = <String, double>{};
    for (final c in await predireAffluence()) {
      affluences['${c.jourIndex}-${c.heure}'] = c.moyennePersonnes;
    }
    final jourDemande = AideDates.indexJourStrftime(date);

    final propositions = <CreneauPropose>[];
    for (final ecart in const [-3, -2, -1, 1, 2, 3]) {
      final candidate = AideDates.decalerHeure(heure, ecart);
      if (candidate == null) continue; // hors service (12h - 22h)

      final prises = await _db.sommePersonnesAcceptees(date, candidate);
      final restantes = restaurant.capaciteMax - prises;
      if (restantes < nbPersonnes) continue; // pas assez de places

      final cleAffluence = '$jourDemande-${candidate.substring(0, 2)}';
      propositions.add(CreneauPropose(
        date: date,
        heure: candidate,
        placesRestantes: restantes,
        affluencePredite: affluences[cleAffluence] ?? 0.0,
        ecartHeures: ecart.abs(),
      ));
    }

    propositions.sort((a, b) {
      final comparaisonEcart = a.ecartHeures.compareTo(b.ecartHeures);
      if (comparaisonEcart != 0) return comparaisonEcart;
      return a.affluencePredite.compareTo(b.affluencePredite);
    });
    return propositions.take(3).toList();
  }
}
