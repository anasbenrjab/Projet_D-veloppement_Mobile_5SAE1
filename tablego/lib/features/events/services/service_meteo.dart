import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/meteo.dart';

/// ---------------------------------------------------------------
/// VALEUR AJOUTÉE — CONSOMMATION D'UN WEB SERVICE EXTERNE
/// ---------------------------------------------------------------
/// Ce service est le seul point de l'application qui appelle une API
/// externe : Open-Meteo (https://open-meteo.com), une API météo publique
/// et gratuite qui ne demande AUCUNE clé d'authentification.
///
/// Tout le reste du module (les 3 fonctions d'IA) reste 100 % local :
/// cette météo sert uniquement d'information contextuelle affichée à
/// côté des prédictions, elle ne participe pas aux calculs.
class ServiceMeteo {
  // Coordonnées de la ville du restaurant (ici Tunis — à modifier si besoin).
  static const double latitude = 36.8065;
  static const double longitude = 10.1815;

  // URL de l'API : on demande uniquement la météo "current".
  static const String urlApi =
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude'
      '&current=temperature_2m,precipitation,weather_code'
      '&timezone=auto';

  final http.Client _client;

  ServiceMeteo({http.Client? client}) : _client = client ?? http.Client();

  /// Récupère la météo actuelle. Renvoie null en cas d'erreur réseau
  /// (hors connexion, API indisponible…) : l'interface masque alors
  /// simplement la carte météo au lieu de planter.
  Future<MeteoActuelle?> recupererMeteoActuelle() async {
    try {
      final reponse = await _client
          .get(Uri.parse(urlApi))
          .timeout(const Duration(seconds: 8));
      if (reponse.statusCode != 200) return null;
      return MeteoActuelle.depuisJson(
          jsonDecode(reponse.body) as Map<String, dynamic>);
    } catch (_) {
      return null; // échec réseau : on dégrade gracieusement
    }
  }
}
