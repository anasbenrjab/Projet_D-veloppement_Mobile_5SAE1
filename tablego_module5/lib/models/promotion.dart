class Promotion {
  int? id;
  int restaurantId;
  String titre;
  String type; // '%' ou 'TND'
  double valeur;
  String code;
  String dateFin; // format 2026-12-31
  int actif; // 1 = active, 0 = desactivee

  Promotion({
    this.id,
    required this.restaurantId,
    required this.titre,
    required this.type,
    required this.valeur,
    required this.code,
    required this.dateFin,
    this.actif = 1,
  });

  bool estExpiree() {
    DateTime fin = DateTime.parse(dateFin);
    DateTime now = DateTime.now();
    DateTime aujourdhui = DateTime(now.year, now.month, now.day);
    return fin.isBefore(aujourdhui);
  }

  String texteReduction() {
    if (type == '%') {
      return '-${valeur.toStringAsFixed(0)} %';
    }
    return '-${valeur.toStringAsFixed(3).replaceAll('.', ',')} TND';
  }

  double calculerReduction(double montant) {
    double r;
    if (type == '%') {
      r = montant * valeur / 100;
    } else {
      r = valeur;
    }
    if (r > montant) r = montant;
    return r;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'titre': titre,
      'type': type,
      'valeur': valeur,
      'code': code,
      'dateFin': dateFin,
      'actif': actif,
    };
  }

  factory Promotion.fromMap(Map<String, dynamic> map) {
    return Promotion(
      id: map['id'],
      restaurantId: map['restaurantId'],
      titre: map['titre'],
      type: map['type'],
      valeur: (map['valeur'] as num).toDouble(),
      code: map['code'],
      dateFin: map['dateFin'],
      actif: map['actif'],
    );
  }
}
