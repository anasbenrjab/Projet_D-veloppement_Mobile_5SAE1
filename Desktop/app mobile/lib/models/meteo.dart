// Modèle d'une prévision météo brute, telle que renvoyée par l'API publique
// Open-Meteo (https://open-meteo.com) — aucune clé API nécessaire.

/// Météo instantanée pour la ville du restaurant.
class MeteoActuelle {
  final double temperature;
  final double precipitation; // mm/h (0 = pas de pluie)
  final int codeMeteo; // code WMO (0 = ciel dégagé, 61 = pluie, 95 = orage…)

  const MeteoActuelle({
    required this.temperature,
    required this.precipitation,
    required this.codeMeteo,
  });

  /// Décodage de la réponse JSON d'Open-Meteo.
  /// Fonction pure (sans appel réseau) pour pouvoir être testée unitairement.
  factory MeteoActuelle.depuisJson(Map<String, dynamic> json) {
    final courant = json['current'] as Map<String, dynamic>;
    return MeteoActuelle(
      temperature: (courant['temperature_2m'] as num).toDouble(),
      precipitation: (courant['precipitation'] as num).toDouble(),
      codeMeteo: (courant['weather_code'] as num).toInt(),
    );
  }

  /// Description courte en français, lisible dans l'interface.
  String get description {
    if (codeMeteo == 0) return 'Ciel dégagé';
    if (codeMeteo <= 2) return 'Partiellement nuageux';
    if (codeMeteo == 3) return 'Couverts';
    if (codeMeteo == 45 || codeMeteo == 48) return 'Brouillard';
    if (codeMeteo >= 95) return 'Orage';
    if (codeMeteo >= 71 && codeMeteo <= 77) return 'Neige';
    if (codeMeteo >= 51) return 'Pluie';
    return 'Temps incertain';
  }

  /// Vrai s'il risque de pleuvoir (utile pour le message contextuel).
  bool get pleut => precipitation > 0 || (codeMeteo >= 51 && codeMeteo <= 67) ||
      (codeMeteo >= 80 && codeMeteo <= 82) || codeMeteo >= 95;
}
