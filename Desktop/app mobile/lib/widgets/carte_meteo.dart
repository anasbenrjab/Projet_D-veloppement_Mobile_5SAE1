import 'package:flutter/material.dart';

import '../models/meteo.dart';
import '../services/service_meteo.dart';

/// Carte affichant la météo actuelle, récupérée sur l'API Open-Meteo.
/// En cas d'échec réseau, la carte reste simplement cachée (état vide
/// gracieux, sans message d'erreur agressif).
class CarteMeteo extends StatefulWidget {
  const CarteMeteo({super.key});

  @override
  State<CarteMeteo> createState() => _CarteMeteoState();
}

class _CarteMeteoState extends State<CarteMeteo> {
  final ServiceMeteo _service = ServiceMeteo();
  MeteoActuelle? _meteo;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final meteo = await _service.recupererMeteoActuelle();
    if (mounted && meteo != null) setState(() => _meteo = meteo);
  }

  IconData get _icone {
    final m = _meteo!;
    if (m.pleut) return Icons.umbrella;
    if (m.codeMeteo == 0) return Icons.wb_sunny;
    return Icons.cloud;
  }

  /// Petite phrase contextuelle : relie la météo extérieure au métier
  /// de la réservation (un restaurant regarde la météo pour anticiper
  /// les couverts et les absences).
  String get _conseil {
    final m = _meteo!;
    if (m.pleut) {
      return 'Pluie prévue : pensez à relancer les clients '
          'pour limiter les no-shows.';
    }
    if (m.temperature >= 30) {
      return 'Fortes chaleurs : la terrasse devrait être très demandée.';
    }
    return 'Conditions agréables : belle soirée en perspective.';
  }

  @override
  Widget build(BuildContext context) {
    final meteo = _meteo;
    if (meteo == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(_icone, size: 40, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Météo en direct : c'est ici la consommation du web service.
                  Text(
                    '${meteo.temperature.round()} °C — ${meteo.description}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _conseil,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Source : API Open-Meteo (météo en direct)',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
