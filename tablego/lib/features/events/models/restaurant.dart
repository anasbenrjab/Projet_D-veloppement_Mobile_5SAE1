/// Modèle du restaurant (un seul restaurant dans cette démo).
class Restaurant {
  final int id;
  final String nom;

  /// Nombre maximum de personnes acceptées par créneau (date + heure).
  /// C'est la référence utilisée par les trois fonctions d'IA.
  final int capaciteMax;

  const Restaurant({
    required this.id,
    required this.nom,
    required this.capaciteMax,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'nom': nom,
        'capacite_max': capaciteMax,
      };

  factory Restaurant.fromMap(Map<String, Object?> map) => Restaurant(
        id: map['id'] as int,
        nom: map['nom'] as String,
        capaciteMax: map['capacite_max'] as int,
      );
}
