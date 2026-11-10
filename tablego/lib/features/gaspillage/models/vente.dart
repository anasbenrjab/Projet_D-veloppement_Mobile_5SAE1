// historique : combien de portions d'un plat ont ete preparees et vendues un jour
// (sert a l'IA pour predire la quantite a preparer)
class Vente {
  int? id;
  int restaurantId;
  String plat;
  int preparees;
  int vendues;
  String date;

  Vente({
    this.id,
    required this.restaurantId,
    required this.plat,
    required this.preparees,
    required this.vendues,
    required this.date,
  });

  int restes() {
    if (preparees > vendues) return preparees - vendues;
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'plat': plat,
      'preparees': preparees,
      'vendues': vendues,
      'date': date,
    };
  }

  factory Vente.fromMap(Map<String, dynamic> map) {
    return Vente(
      id: map['id'],
      restaurantId: map['restaurantId'],
      plat: map['plat'],
      preparees: map['preparees'],
      vendues: map['vendues'],
      date: map['date'],
    );
  }
}
