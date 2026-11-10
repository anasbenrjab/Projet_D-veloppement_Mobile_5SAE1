/// Outils de manipulation des dates et heures.
///
/// Dans la base SQLite, les dates sont du texte "AAAA-MM-JJ" et les heures
/// "HH:MM". Ce format a deux avantages : il se trie naturellement dans le
/// bon ordre chronologique, et il est directement compris par les fonctions
/// SQL comme `strftime`.
class AideDates {
  /// Noms des jours indexés comme `strftime('%w')` de SQLite :
  /// 0 = Dimanche, 1 = Lundi, ... 6 = Samedi.
  static const List<String> nomsJours = [
    'Dimanche',
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
  ];

  static const List<String> _nomsMois = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  /// Bornes du service en heures (les créneaux vont de 12h à 22h).
  static const int heureOuverture = 12;
  static const int heureFermeture = 22;

  /// Convertit un [DateTime] en texte "AAAA-MM-JJ" pour la base.
  static String versTexte(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final j = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$j';
  }

  /// Date du jour au format "AAAA-MM-JJ".
  static String dateDuJour() => versTexte(DateTime.now());

  /// Transforme "2026-03-20" en "Vendredi 20 mars" (affichage français).
  static String formaterDateLongue(String date) {
    final d = DateTime.parse(date);
    return '${nomsJours[d.weekday % 7]} ${d.day} ${_nomsMois[d.month - 1]}';
  }

  /// Nom du jour de la semaine pour une date "AAAA-MM-JJ" (ex. "Vendredi").
  ///
  /// `DateTime.weekday` va de 1 (lundi) à 7 (dimanche) : le modulo 7 le
  /// ramène sur l'indexation dimanche = 0 utilisée par SQLite.
  static String jourDeLaSemaine(String date) =>
      nomsJours[DateTime.parse(date).weekday % 7];

  /// Index au format `strftime('%w')` (0 = dimanche) d'une date "AAAA-MM-JJ".
  static int indexJourStrftime(String date) => DateTime.parse(date).weekday % 7;

  /// Nombre de jours entre aujourd'hui et la [date] de réservation.
  ///
  /// Exemple : si nous sommes le 10 et que la réservation est le 20,
  /// le résultat est 10 (la réservation a été prise 10 jours à l'avance).
  static int joursDavance(String date) {
    final n = DateTime.now();
    final d = DateTime.parse(date);
    final aujourdhui = DateTime(n.year, n.month, n.day);
    final jourReserve = DateTime(d.year, d.month, d.day);
    return jourReserve.difference(aujourdhui).inDays;
  }

  /// Décale une heure "HH:MM" de [deltaHeures] heures.
  ///
  /// Renvoie null si le résultat sort des heures d'ouverture (12h - 22h) :
  /// l'IA ne proposera jamais un créneau en dehors du service.
  static String? decalerHeure(String heure, int deltaHeures) {
    final parties = heure.split(':');
    final totalMinutes =
        int.parse(parties[0]) * 60 + int.parse(parties[1]) + deltaHeures * 60;
    // Comparaison en MINUTES : "22:30" dépasse la fermeture (22:00) même si
    // son heure (22) semble dans la plage.
    if (totalMinutes < heureOuverture * 60 ||
        totalMinutes > heureFermeture * 60) {
      return null;
    }
    final h = totalMinutes ~/ 60;
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m';
  }

  /// Moment actuel au format ISO 8601 (colonne `created_at`).
  static String maintenantIso() => DateTime.now().toIso8601String();
}
