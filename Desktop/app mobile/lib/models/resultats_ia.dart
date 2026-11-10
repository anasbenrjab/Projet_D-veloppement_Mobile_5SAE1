// Résultats renvoyés par les fonctions d'IA locale (voir `ai_service.dart`).

/// Affluence prédite pour un créneau récurrent (jour de la semaine + heure).
class CreneauAffluence {
  /// Index du jour au format SQLite `strftime('%w')` : 0 = dimanche ... 6 = samedi.
  final int jourIndex;
  final String jourNom; // ex. "Samedi"
  final String heure; // ex. "20" (extrait de "20:30")
  final double moyennePersonnes; // moyenne de personnes présentes
  final bool charge; // vrai si la moyenne dépasse 80 % de la capacité

  const CreneauAffluence({
    required this.jourIndex,
    required this.jourNom,
    required this.heure,
    required this.moyennePersonnes,
    required this.charge,
  });

  /// Exemple : "85 %" de la capacité maximale.
  int pourcentageRemplissage(int capaciteMax) =>
      (moyennePersonnes / capaciteMax * 100).round();
}

/// Un créneau alternatif proposé au client quand son choix est complet.
class CreneauPropose {
  final String date; // AAAA-MM-JJ
  final String heure; // HH:MM
  final int placesRestantes;
  final double affluencePredite; // moyenne de personnes à ce type de créneau
  final int ecartHeures; // écart avec l'heure demandée (1, 2 ou 3)

  const CreneauPropose({
    required this.date,
    required this.heure,
    required this.placesRestantes,
    required this.affluencePredite,
    required this.ecartHeures,
  });
}
