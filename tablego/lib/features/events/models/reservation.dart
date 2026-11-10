/// Modèle d'une réservation de table.
///
/// Chaque champ correspond à une colonne de la table `reservation` de SQLite.
/// Les dates sont stockées en texte : "AAAA-MM-JJ" pour la date, "HH:MM"
/// pour l'heure. Ce format se compare naturellement (ordre chronologique)
/// et est directement compatible avec les fonctions SQL `strftime`.
class Reservation {
  // Valeurs possibles de la colonne `statut`.
  static const String statutEnAttente = 'en_attente';
  static const String statutAcceptee = 'acceptee';
  static const String statutRefusee = 'refusee';
  static const String statutAnnulee = 'annulee';
  static const String statutHonoree = 'honoree';
  static const String statutNoShow = 'no_show';

  final int? id; // null tant que la réservation n'est pas enregistrée
  final int clientId;
  final int restaurantId;
  final String date; // AAAA-MM-JJ
  final String heure; // HH:MM
  final int nbPersonnes;
  final String statut;
  final int nbModifications; // incrémenté à chaque modification par le client
  final double scoreNoShow; // score de risque calculé par l'IA locale (0 à 1)
  final String createdAt; // moment de création de la demande (ISO 8601)

  /// Nom du restaurant (lecture seule, rempli par la jointure de
  /// `reservationsDuClient` ; jamais écrit en base).
  final String? nomRestaurant;

  const Reservation({
    this.id,
    required this.clientId,
    required this.restaurantId,
    required this.date,
    required this.heure,
    required this.nbPersonnes,
    required this.statut,
    this.nbModifications = 0,
    this.scoreNoShow = 0.0,
    required this.createdAt,
    this.nomRestaurant,
  });

  /// Convertit l'objet en carte pour l'insertion SQL (requêtes paramétrées).
  Map<String, Object?> toMap() => {
        'id': id,
        'client_id': clientId,
        'restaurant_id': restaurantId,
        'date': date,
        'heure': heure,
        'nb_personnes': nbPersonnes,
        'statut': statut,
        'nb_modifications': nbModifications,
        'score_no_show': scoreNoShow,
        'created_at': createdAt,
      };

  /// Reconstruit l'objet depuis une ligne de résultat SQL.
  factory Reservation.fromMap(Map<String, Object?> map) => Reservation(
        id: map['id'] as int?,
        clientId: map['client_id'] as int,
        restaurantId: map['restaurant_id'] as int,
        date: map['date'] as String,
        heure: map['heure'] as String,
        nbPersonnes: map['nb_personnes'] as int,
        statut: map['statut'] as String,
        nbModifications: (map['nb_modifications'] as int?) ?? 0,
        scoreNoShow: ((map['score_no_show'] as num?) ?? 0).toDouble(),
        createdAt: (map['created_at'] as String?) ?? '',
        nomRestaurant: map['nom_restaurant'] as String?,
      );

  /// Une réservation est modifiable/annulable tant qu'elle est en attente ou
  /// acceptée et que la date n'est pas passée.
  bool get estModifiable =>
      (statut == statutEnAttente || statut == statutAcceptee) &&
      date.compareTo(_dateDuJourIso()) >= 0;

  String _dateDuJourIso() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final j = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$j';
  }
}
