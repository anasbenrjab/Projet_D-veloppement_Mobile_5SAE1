import '../outils.dart';

class Ingredient {
  int? id;
  int restaurantId;
  String nom;
  double quantite;
  String unite; // 'kg', 'L' ou 'pièce'
  double cout; // prix d'une unite en TND
  String datePeremption; // format 2026-12-31

  Ingredient({
    this.id,
    required this.restaurantId,
    required this.nom,
    required this.quantite,
    required this.unite,
    required this.cout,
    required this.datePeremption,
  });

  int joursAvantPeremption() {
    return joursRestants(datePeremption);
  }

  bool estPerime() {
    return joursAvantPeremption() < 0;
  }

  // alerte : il reste 3 jours ou moins
  bool expireBientot() {
    int j = joursAvantPeremption();
    return j >= 0 && j <= 3;
  }

  double valeurStock() {
    return quantite * cout;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'nom': nom,
      'quantite': quantite,
      'unite': unite,
      'cout': cout,
      'datePeremption': datePeremption,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'],
      restaurantId: map['restaurantId'],
      nom: map['nom'],
      quantite: (map['quantite'] as num).toDouble(),
      unite: map['unite'],
      cout: (map['cout'] as num).toDouble(),
      datePeremption: map['datePeremption'],
    );
  }
}
