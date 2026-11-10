/// Modèle d'un événement organisé par le restaurant (module CRUD complet).
class Evenement {
  // Valeurs possibles de la colonne `type`.
  static const String typeAnniversaire = 'anniversaire';
  static const String typeSoiree = 'soiree';
  static const String typeMusiqueLive = 'musique_live';

  /// Libellés français affichés dans l'interface.
  static const Map<String, String> libellesTypes = {
    typeAnniversaire: 'Anniversaire',
    typeSoiree: 'Soirée',
    typeMusiqueLive: 'Musique live',
  };

  final int? id;
  final int restaurantId;
  final String titre;
  final String type;
  final String date; // AAAA-MM-JJ
  final String description;
  final int placesTotal;
  final int placesRestantes;

  const Evenement({
    this.id,
    required this.restaurantId,
    required this.titre,
    required this.type,
    required this.date,
    required this.description,
    required this.placesTotal,
    required this.placesRestantes,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'restaurant_id': restaurantId,
        'titre': titre,
        'type': type,
        'date': date,
        'description': description,
        'places_total': placesTotal,
        'places_restantes': placesRestantes,
      };

  factory Evenement.fromMap(Map<String, Object?> map) => Evenement(
        id: map['id'] as int?,
        restaurantId: map['restaurant_id'] as int,
        titre: map['titre'] as String,
        type: map['type'] as String,
        date: map['date'] as String,
        description: (map['description'] as String?) ?? '',
        placesTotal: map['places_total'] as int,
        placesRestantes: map['places_restantes'] as int,
      );
}
