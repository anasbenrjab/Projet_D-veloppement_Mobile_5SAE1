import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/resultats_ia.dart';
import '../../services/ai_service.dart';
import '../../widgets/carte_meteo.dart';
import '../../widgets/etat_vide.dart';

/// Onglet "Affluence IA" : la prédiction des heures chargées de la semaine,
/// calculée à partir de l'historique des réservations (100 % local).
///
/// Un créneau est signalé "très chargé" quand la moyenne de personnes
/// dépasse 80 % de la capacité maximale du restaurant.
class EcranAffluence extends StatefulWidget {
  const EcranAffluence({super.key});

  @override
  State<EcranAffluence> createState() => _EcranAffluenceState();
}

class _EcranAffluenceState extends State<EcranAffluence>
    with AutomaticKeepAliveClientMixin {
  final AiService _ia = AiService();
  late Future<(List<CreneauAffluence>, int)> _predictions;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _predictions = _charger();
  }

  Future<(List<CreneauAffluence>, int)> _charger() async {
    final resultats = await _ia.predireAffluence();
    final restaurant = await DatabaseHelper.instance.restaurantPrincipal();
    return (resultats, restaurant.capaciteMax);
  }

  void _rafraichir() {
    setState(() => _predictions = _charger());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<(List<CreneauAffluence>, int)>(
      future: _predictions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EtatVide(
            icone: Icons.error_outline,
            titre: 'Erreur de calcul',
            message: snapshot.error.toString(),
          );
        }
        final (creneaux, capacite) =
            snapshot.data ?? (const <CreneauAffluence>[], 40);
        final seuil = capacite * 0.8;
        final charges = creneaux.where((c) => c.charge).toList();

        return RefreshIndicator(
          onRefresh: () async => _rafraichir(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ---- Météo en direct (API externe Open-Meteo) --------------
              const CarteMeteo(),
              const SizedBox(height: 8),

              // ---- Bandeau d'alerte ------------------------------------
              Card(
                color: charges.isEmpty
                    ? Colors.green.withAlpha(30)
                    : Colors.red.withAlpha(40),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        charges.isEmpty
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: charges.isEmpty ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          charges.isEmpty
                              ? 'Aucun créneau très chargé pour le moment.'
                              : _libelleAlerte(charges),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Analyse de l\'historique des 8 dernières semaines · '
                  'seuil d\'alerte : ${seuil.toStringAsFixed(0)} personnes '
                  '(80 % de $capacite).',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),

              // ---- Liste des créneaux, du plus chargé au plus calme -----
              if (creneaux.isEmpty)
                const EtatVide(
                  icone: Icons.insights,
                  titre: 'Pas encore assez d\'historique',
                  message:
                      'Les prédictions apparaîtront dès que des réservations '
                      'seront enregistrées.',
                )
              else
                ...creneaux.map((c) => _carteCreneau(c, capacite)),
            ],
          ),
        );
      },
    );
  }

  /// Exemple : "2 créneaux très chargés : Samedi 20h, Vendredi 20h".
  String _libelleAlerte(List<CreneauAffluence> charges) {
    final noms = charges.take(3).map((c) => '${c.jourNom} ${c.heure}h').join(', ');
    final suffixe = charges.length > 3 ? '…' : '';
    return '${charges.length} créneau(x) très chargé(s) : $noms$suffixe';
  }

  Widget _carteCreneau(CreneauAffluence c, int capacite) {
    final pourcentage = c.pourcentageRemplissage(capacite);
    final moyenneTexte =
        c.moyennePersonnes.toStringAsFixed(1).replaceAll('.', ',');
    final couleur = c.charge ? Colors.red : Colors.blueGrey;

    return Card(
      shape: c.charge
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.red, width: 1.5),
            )
          : null,
      child: ListTile(
        leading: Icon(
          c.charge ? Icons.local_fire_department : Icons.restaurant,
          color: couleur,
          size: 32,
        ),
        title: Text(
          '${c.jourNom} ${c.heure}h',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: c.charge ? Colors.red : null,
          ),
        ),
        subtitle: Text(
          c.charge
              ? 'Très chargé · moyenne $moyenneTexte personnes ($pourcentage %)'
              : 'Moyenne $moyenneTexte personnes ($pourcentage %)',
        ),
        trailing: c.charge
            ? const Text(
                'CHARGÉ',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              )
            : null,
      ),
    );
  }
}
