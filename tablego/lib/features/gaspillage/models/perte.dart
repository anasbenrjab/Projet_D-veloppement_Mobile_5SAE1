// une ligne du journal de gaspillage
class Perte {
  int? id;
  int restaurantId;
  String produit;
  double quantite;
  String unite;
  String raison; // voir la liste raisons
  double cout; // cout total de la perte en TND
  String date; // format 2026-10-15

  static List<String> raisons = [
    'Périmé',
    'Surproduction',
    'Abîmé',
    'Retour client',
    'Autre',
  ];

  Perte({
    this.id,
    required this.restaurantId,
    required this.produit,
    required this.quantite,
    required this.unite,
    required this.raison,
    required this.cout,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'produit': produit,
      'quantite': quantite,
      'unite': unite,
      'raison': raison,
      'cout': cout,
      'date': date,
    };
  }

  factory Perte.fromMap(Map<String, dynamic> map) {
    return Perte(
      id: map['id'],
      restaurantId: map['restaurantId'],
      produit: map['produit'],
      quantite: (map['quantite'] as num).toDouble(),
      unite: map['unite'],
      raison: map['raison'],
      cout: (map['cout'] as num).toDouble(),
      date: map['date'],
    );
  }
}
