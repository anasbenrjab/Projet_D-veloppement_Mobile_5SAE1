import 'package:flutter_test/flutter_test.dart';

import 'package:resto_events/models/meteo.dart';
import 'package:resto_events/models/resultats_ia.dart';
import 'package:resto_events/services/ai_service.dart';
import 'package:resto_events/utils/aide_dates.dart';

/// Tests unitaires des fonctions pures du module (sans base de données) :
/// la formule de score de no-show et les utilitaires de dates/heures.
void main() {
  group('Score de risque de no-show (formule IA n°2)', () {
    test('Cas de base : 0.10 sans aucun facteur de risque', () {
      expect(
        AiService.formuleScoreNoShow(
          aDejaNoShow: false,
          joursDavance: 2,
          nbPersonnes: 2,
          nbModifications: 0,
        ),
        closeTo(0.10, 0.0001),
      );
    });

    test('Un client récidiviste ajoute +0.40', () {
      expect(
        AiService.formuleScoreNoShow(
          aDejaNoShow: true,
          joursDavance: 2,
          nbPersonnes: 2,
          nbModifications: 0,
        ),
        closeTo(0.50, 0.0001),
      );
    });

    test('7 jours d\'avance exactement : PAS de bonus (seuil strict > 7)', () {
      expect(
        AiService.formuleScoreNoShow(
          aDejaNoShow: false,
          joursDavance: 7,
          nbPersonnes: 2,
          nbModifications: 0,
        ),
        closeTo(0.10, 0.0001),
      );
    });

    test('8 jours d\'avance : bonus +0.20', () {
      expect(
        AiService.formuleScoreNoShow(
          aDejaNoShow: false,
          joursDavance: 8,
          nbPersonnes: 2,
          nbModifications: 0,
        ),
        closeTo(0.30, 0.0001),
      );
    });

    test('Groupe de 6 personnes : pas de bonus ; 7 personnes : +0.10', () {
      final six = AiService.formuleScoreNoShow(
        aDejaNoShow: false,
        joursDavance: 0,
        nbPersonnes: 6,
        nbModifications: 0,
      );
      final sept = AiService.formuleScoreNoShow(
        aDejaNoShow: false,
        joursDavance: 0,
        nbPersonnes: 7,
        nbModifications: 0,
      );
      expect(six, closeTo(0.10, 0.0001));
      expect(sept, closeTo(0.20, 0.0001));
    });

    test('2 modifications ou plus : +0.10', () {
      expect(
        AiService.formuleScoreNoShow(
          aDejaNoShow: false,
          joursDavance: 0,
          nbPersonnes: 2,
          nbModifications: 2,
        ),
        closeTo(0.20, 0.0001),
      );
    });

    test('Tous les facteurs cumulés : 0.90', () {
      expect(
        AiService.formuleScoreNoShow(
          aDejaNoShow: true,
          joursDavance: 10,
          nbPersonnes: 8,
          nbModifications: 3,
        ),
        closeTo(0.90, 0.0001),
      );
    });
  });

  group('Décalage d\'heure (utilisé par les créneaux alternatifs IA n°3)', () {
    test('Décalage simple d\'une heure', () {
      expect(AideDates.decalerHeure('20:00', 1), '21:00');
      expect(AideDates.decalerHeure('20:00', -1), '19:00');
    });

    test('Les minutes sont conservées', () {
      expect(AideDates.decalerHeure('19:30', 2), '21:30');
    });

    test('Hors service (après 22h ou avant 12h) : null', () {
      expect(AideDates.decalerHeure('21:30', 1), isNull); // 22:30 refusé
      expect(AideDates.decalerHeure('12:00', -1), isNull); // 11:00 refusé
    });

    test('Les bornes du service restent valides', () {
      expect(AideDates.decalerHeure('21:00', 1), '22:00');
      expect(AideDates.decalerHeure('13:00', -1), '12:00');
    });
  });

  group('Formatage des dates françaises', () {
    test('Date longue en français', () {
      expect(AideDates.formaterDateLongue('2026-03-20'), 'Vendredi 20 mars');
    });

    test('Index de jour au format strftime (0 = dimanche)', () {
      expect(AideDates.indexJourStrftime('2026-03-20'), 5); // vendredi
      expect(AideDates.indexJourStrftime('2026-03-22'), 0); // dimanche
    });

    test('Demain : 1 jour d\'avance', () {
      final demain = DateTime.now().add(const Duration(days: 1));
      expect(AideDates.joursDavance(AideDates.versTexte(demain)), 1);
    });
  });

  group('Pourcentage de remplissage (prédiction IA n°1)', () {
    test('Calcul du pourcentage par rapport à la capacité', () {
      const creneau = CreneauAffluence(
        jourIndex: 6,
        jourNom: 'Samedi',
        heure: '20',
        moyennePersonnes: 34.0,
        charge: true,
      );
      expect(creneau.pourcentageRemplissage(40), 85);
    });
  });

  group('Météo externe (valeur ajoutée — API Open-Meteo)', () {
    test('Décodage de la réponse JSON de l\'API', () {
      final meteo = MeteoActuelle.depuisJson(const {
        'current': {
          'temperature_2m': 22.4,
          'precipitation': 0.0,
          'weather_code': 1,
        },
      });
      expect(meteo.temperature, 22.4);
      expect(meteo.codeMeteo, 1);
      expect(meteo.pleut, isFalse);
    });

    test('Un code pluie est reconnu comme "il pleut"', () {
      final meteo = MeteoActuelle.depuisJson(const {
        'current': {
          'temperature_2m': 15.0,
          'precipitation': 2.5,
          'weather_code': 61,
        },
      });
      expect(meteo.pleut, isTrue);
      expect(meteo.description, 'Pluie');
    });
  });
}
