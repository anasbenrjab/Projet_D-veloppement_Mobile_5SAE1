/// Modèle d'un client (identification simplifiée : juste un nom de profil).
class Client {
  final int id;
  final String nom;

  const Client({required this.id, required this.nom});

  Map<String, Object?> toMap() => {'id': id, 'nom': nom};

  factory Client.fromMap(Map<String, Object?> map) => Client(
        id: map['id'] as int,
        nom: map['nom'] as String,
      );
}
