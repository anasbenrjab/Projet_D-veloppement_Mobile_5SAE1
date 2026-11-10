import 'package:flutter/material.dart';

import '../../database/evenements_repository.dart';
import '../../models/reservation.dart';
import '../../utils/aide_dates.dart';
import '../../widgets/etat_vide.dart';
import '../../widgets/pastille_statut.dart';
import 'ecran_formulaire_reservation.dart';

/// Écran d'accueil du client : la liste de toutes ses réservations avec
/// leur statut, la possibilité de modifier ou d'annuler, et un bouton
/// pour créer une nouvelle réservation.
class EcranMesReservations extends StatefulWidget {
  final int clientId;

  const EcranMesReservations(
      {super.key, required this.clientId, this.restaurantId});

  /// Intégration TableGo : non null = réservations chez ce restaurant
  /// (`restaurant_profiles.id`) avec le bouton « Réserver » ; null = toutes
  /// les réservations du client (onglet Activité), sans création.
  final int? restaurantId;

  @override
  State<EcranMesReservations> createState() => _EcranMesReservationsState();
}

class _EcranMesReservationsState extends State<EcranMesReservations> {
  final EvenementsRepository _db = EvenementsRepository.instance;

  List<Reservation> _reservations = [];
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
      final liste = await _db.reservationsDuClient(widget.clientId,
          restaurantId: widget.restaurantId);
      // Tri "intelligent" : les réservations à venir d'abord (les plus
      // proches en premier), puis l'historique (le plus récent d'abord).
      final aujourdhui = AideDates.dateDuJour();
      liste.sort((a, b) {
        final cleA = '${a.date} ${a.heure}';
        final cleB = '${b.date} ${b.heure}';
        final aFuture = a.date.compareTo(aujourdhui) >= 0;
        final bFuture = b.date.compareTo(aujourdhui) >= 0;
        if (aFuture != bFuture) return aFuture ? -1 : 1;
        return aFuture ? cleA.compareTo(cleB) : cleB.compareTo(cleA);
      });
      if (!mounted) return;
      setState(() => _reservations = liste);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _annuler(Reservation r) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: Text(
          '${AideDates.formaterDateLongue(r.date)} à ${r.heure} — '
          '${r.nbPersonnes} personne(s).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await _db.changerStatutReservation(r.id!, Reservation.statutAnnulee);
      await _charger();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réservation annulée.')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _charger,
          ),
        ],
      ),
      floatingActionButton: widget.restaurantId == null
          ? null
          : FloatingActionButton.extended(
        heroTag: 'nouvelle_reservation',
        icon: const Icon(Icons.add),
        label: const Text('Réserver'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EcranFormulaireReservation(
                clientId: widget.clientId,
                restaurantId: widget.restaurantId!,
                onEnregistre: _charger,
              ),
            ),
          );
        },
      ),
      body: _construireCorps(),
    );
  }

  Widget _construireCorps() {
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
    if (_reservations.isEmpty) {
      return EtatVide(
        icone: Icons.event_busy,
        titre: 'Aucune réservation',
        message: widget.restaurantId != null
            ? 'Appuyez sur « Réserver » pour créer votre première demande.'
            : "Choisissez un restaurant (Explorer) puis l'onglet "
                '« Réserver » pour créer votre première demande.',
      );
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: _reservations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final r = _reservations[index];
          final modifiable = r.estModifiable;
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      r.date.compareTo(AideDates.dateDuJour()) >= 0
                          ? Icons.upcoming
                          : Icons.history,
                      color: Colors.deepOrange,
                    ),
                    title: Text(
                      '${AideDates.formaterDateLongue(r.date)} à ${r.heure}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${r.nomRestaurant != null && widget.restaurantId == null ? '${r.nomRestaurant} · ' : ''}'
                      '${r.nbPersonnes} personne(s)'
                      '${r.nbModifications > 0 ? ' · modifiée ${r.nbModifications} fois' : ''}',
                    ),
                    trailing: PastilleStatut(statut: r.statut),
                  ),
                  if (modifiable)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Modifier'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EcranFormulaireReservation(
                                clientId: widget.clientId,
                                restaurantId: r.restaurantId,
                                reservationExistante: r,
                                onEnregistre: _charger,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Annuler',
                              style: TextStyle(color: Colors.red)),
                          onPressed: () => _annuler(r),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
