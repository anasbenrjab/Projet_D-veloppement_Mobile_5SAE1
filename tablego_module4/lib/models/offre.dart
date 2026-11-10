import '../outils.dart';

// offre anti-gaspi : un plat a prix reduit en fin de service
class Offre {
  int? id;
  int restaurantId;
  String plat;
  double prixInitial;
  double prixReduit;
  int quantite; // portions encore disponibles
  String date; // jour de l'offre, format 2026-10-15
  String heureFin; // l'offre se termine a cette heure, ex "23:00"

  Offre({
    this.id,
    required this.restaurantId,
    required this.plat,
    required this.prixInitial,
    required this.prixReduit,
    required this.quantite,
    required this.date,
    required this.heureFin,
  });

  int pourcentage() {
    if (prixInitial == 0) return 0;
    return ((prixInitial - prixReduit) / prixInitial * 100).round();
  }

  // terminee si le jour est passe, ou si c'est aujourd'hui et l'heure est passee
  bool estTerminee() {
    int j = joursRestants(date);
    if (j < 0) return true;
    if (j > 0) return false;
    DateTime now = DateTime.now();
    int maintenant = now.hour * 60 + now.minute;
    return maintenant >= minutes(heureFin);
  }

  // le client peut reserver : pas terminee et il reste des portions
  bool estDisponible() {
    return !estTerminee() && quantite > 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'plat': plat,
      'prixInitial': prixInitial,
      'prixReduit': prixReduit,
      'quantite': quantite,
      'date': date,
      'heureFin': heureFin,
    };
  }

  factory Offre.fromMap(Map<String, dynamic> map) {
    return Offre(
      id: map['id'],
      restaurantId: map['restaurantId'],
      plat: map['plat'],
      prixInitial: (map['prixInitial'] as num).toDouble(),
      prixReduit: (map['prixReduit'] as num).toDouble(),
      quantite: map['quantite'],
      date: map['date'],
      heureFin: map['heureFin'],
    );
  }
}
