import 'package:flutter/material.dart';

import '../models/resultats_ia.dart';
import '../utils/aide_dates.dart';

/// Feuille inférieure (bottom sheet) affichée au client quand le créneau
/// demandé est complet : elle liste les créneaux alternatifs proposés par
/// l'IA, un appui suffit pour en choisir un.
///
/// Résultat renvoyé :
///   - un [CreneauPropose] si le client choisit une proposition ;
///   - la chaîne "maintenir" s'il garde quand même son créneau initial ;
///   - null si la feuille est fermée sans choisir (on abandonne la création).
class FeuilleCreneauxAlternatifs extends StatelessWidget {
  final List<CreneauPropose> propositions;

  const FeuilleCreneauxAlternatifs({super.key, required this.propositions});

  static Future<Object?> afficher(
    BuildContext context, {
    required List<CreneauPropose> propositions,
  }) {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          FeuilleCreneauxAlternatifs(propositions: propositions),
    );
  }

  /// Libellé qualitative de l'affluence prédite.
  String _libelleAffluence(double moyenne) {
    if (moyenne < 15) return 'affluence faible';
    if (moyenne < 25) return 'affluence moyenne';
    return 'affluence forte';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.deepOrange.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Créneau complet — suggestions du service',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ce créneau dépasse la capacité du restaurant. '
              'Voici les heures les plus proches avec assez de places :',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            // Aucun créneau disponible : message clair plutôt que liste vide.
            if (propositions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aucun créneau alternatif disponible ce jour-là '
                  '(service de 12h à 22h). Essayez une autre date.',
                ),
              )
            else
              ...propositions.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available,
                        color: Colors.green),
                    title: Text(
                        '${AideDates.formaterDateLongue(p.date)} à ${p.heure}'),
                    subtitle: Text(
                      '${p.placesRestantes} places libres · '
                      '${_libelleAffluence(p.affluencePredite)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, p),
                  )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, 'maintenir'),
                child: const Text('Maintenir ma demande initiale'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
