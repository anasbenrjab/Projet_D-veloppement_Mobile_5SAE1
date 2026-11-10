// le client reserve des portions d'une offre anti-gaspi
class ReservationOffre {
  int? id;
  int offreId;
  int clientId;
  String clientNom;
  int quantite;
  String date;

  // pas dans la table : rempli avec une jointure pour l'affichage
  String? plat;
  double? prixReduit;
  String? heureFin;
  String? dateOffre;

  ReservationOffre({
    this.id,
    required this.offreId,
    required this.clientId,
    required this.clientNom,
    required this.quantite,
    required this.date,
    this.plat,
    this.prixReduit,
    this.heureFin,
    this.dateOffre,
  });

  double total() {
    return quantite * (prixReduit ?? 0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'offreId': offreId,
      'clientId': clientId,
      'clientNom': clientNom,
      'quantite': quantite,
      'date': date,
    };
  }

  factory ReservationOffre.fromMap(Map<String, dynamic> map) {
    return ReservationOffre(
      id: map['id'],
      offreId: map['offreId'],
      clientId: map['clientId'],
      clientNom: map['clientNom'],
      quantite: map['quantite'],
      date: map['date'],
      plat: map['plat'],
      prixReduit:
          map['prixReduit'] == null ? null : (map['prixReduit'] as num).toDouble(),
      heureFin: map['heureFin'],
      dateOffre: map['dateOffre'],
    );
  }
}
