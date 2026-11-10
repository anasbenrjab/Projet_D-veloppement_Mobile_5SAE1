class Avis {
  int? id;
  int restaurantId;
  int clientId;
  String clientNom;
  int note;
  String commentaire;
  String date;
  String? reponse;
  String sentiment; // positif, neutre ou negatif (calcule par l'IA)
  int spam; // 0 ou 1

  Avis({
    this.id,
    required this.restaurantId,
    required this.clientId,
    required this.clientNom,
    required this.note,
    required this.commentaire,
    required this.date,
    this.reponse,
    required this.sentiment,
    this.spam = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'clientId': clientId,
      'clientNom': clientNom,
      'note': note,
      'commentaire': commentaire,
      'date': date,
      'reponse': reponse,
      'sentiment': sentiment,
      'spam': spam,
    };
  }

  factory Avis.fromMap(Map<String, dynamic> map) {
    return Avis(
      id: map['id'],
      restaurantId: map['restaurantId'],
      clientId: map['clientId'],
      clientNom: map['clientNom'],
      note: map['note'],
      commentaire: map['commentaire'],
      date: map['date'],
      reponse: map['reponse'],
      sentiment: map['sentiment'],
      spam: map['spam'],
    );
  }
}
