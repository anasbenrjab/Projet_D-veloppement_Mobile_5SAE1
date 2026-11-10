import 'package:flutter/material.dart';

import '../../database/evenements_repository.dart';
import '../../models/reservation.dart';
import '../../utils/aide_dates.dart';
import '../../widgets/badge_no_show.dart';
import '../../widgets/etat_vide.dart';
import '../../widgets/pastille_statut.dart';

/// Onglet "Demandes" du restaurant : la liste des demandes de réservation
/// avec, à côté de chacune, le badge de risque de no-show calculé par l'IA.
/// Le restaurant peut ACCEPTER ou REFUSER, et clôturer une réservation
/// passée en la marquant "honorée" ou "no-show" (ce qui nourrit l'IA).
class EcranDemandes extends StatefulWidget {
  const EcranDemandes({super.key, required this.restaurantId});

  /// `restaurant_profiles.id` du restaurant connecté (intégration TableGo :
  /// le Module 3 utilisait son unique restaurant, id 1).
  final int restaurantId;

  @override
  State<EcranDemandes> createState() => _EcranDemandesState();
}

/// Petite structure interne : une réservation + le nom de son client.
class _Demande {
  final Reservation reservation;
  final String nomClient;
  const _Demande(this.reservation, this.nomClient);
}

class _EcranDemandesState extends State<EcranDemandes> {
  final EvenementsRepository _db = EvenementsRepository.instance;

  bool _afficherToutes = false;
  List<_Demande> _demandes = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final lignes = await _db.reservationsAvecClient(
        restaurantId: widget.restaurantId,
        statut: _afficherToutes ? null : Reservation.statutEnAttente,
      );
      if (!mounted) return;
      setState(() {
        _demandes = lignes
            .map((l) => _Demande(
                  Reservation.fromMap(l),
                  (l['nom_client'] as String?) ?? '?',
                ))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _changerStatut(_Demande d, String statut) async {
    try {
      await _db.changerStatutReservation(d.reservation.id!, statut);
      await _charger();
      if (!mounted) return;
      final libelles = {
        Reservation.statutAcceptee: 'Réservation acceptée',
        Reservation.statutRefusee: 'Réservation refusée',
        Reservation.statutHonoree: 'Réservation honorée',
        Reservation.statutNoShow: 'Client marqué no-show',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(libelles[statut] ?? 'Statut mis à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtre : seulement les demandes à traiter, ou tout l'historique.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('En attente'),
                selected: !_afficherToutes,
                onSelected: (_) => setState(() {
                  _afficherToutes = false;
                  _charger();
                }),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Toutes'),
                selected: _afficherToutes,
                onSelected: (_) => setState(() {
                  _afficherToutes = true;
                  _charger();
                }),
              ),
            ],
          ),
        ),
        Expanded(child: _construireListe()),
      ],
    );
  }

  Widget _construireListe() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return EtatVide(
        icone: Icons.error_outline,
        titre: 'Une erreur est survenue',
        message: _erreur!,
      );
    }
    if (_demandes.isEmpty) {
      return EtatVide(
        icone: Icons.inbox,
        titre: _afficherToutes ? 'Aucune réservation' : 'Aucune demande en attente',
        message: _afficherToutes
            ? 'La base ne contient aucune réservation.'
            : 'Les nouvelles demandes des clients apparaîtront ici.',
      );
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _demandes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _carteDemande(_demandes[index]),
      ),
    );
  }

  Widget _carteDemande(_Demande d) {
    final r = d.reservation;
    final datePassee = r.date.compareTo(AideDates.dateDuJour()) < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${d.nomClient} · ${r.nbPersonnes} personne(s)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                // Le badge IA : risque que ce client ne se présente pas.
                BadgeNoShow(score: r.scoreNoShow),
              ],
            ),
            const SizedBox(height: 4),
            Text('${AideDates.formaterDateLongue(r.date)} à ${r.heure}'),
            const SizedBox(height: 8),
            Row(
              children: [
                PastilleStatut(statut: r.statut),
                const Spacer(),
                if (r.statut == Reservation.statutEnAttente) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () =>
                        _changerStatut(d, Reservation.statutRefusee),
                    child: const Text('Refuser'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.green),
                    onPressed: () =>
                        _changerStatut(d, Reservation.statutAcceptee),
                    child: const Text('Accepter'),
                  ),
                ] else if (r.statut == Reservation.statutAcceptee &&
                    datePassee)
                  // Après le service, on clôture la réservation : c'est ce
                  // qui crée les no-shows utilisés par le score de risque.
                  PopupMenuButton<String>(
                    tooltip: 'Clôturer la réservation',
                    onSelected: (statut) => _changerStatut(d, statut),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: Reservation.statutHonoree,
                        child: Text('Marquer honorée'),
                      ),
                      PopupMenuItem(
                        value: Reservation.statutNoShow,
                        child: Text('Marquer no-show'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
