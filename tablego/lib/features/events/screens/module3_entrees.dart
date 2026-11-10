/// TableGo — Module 3 : Événements & Réservations.
///
/// Integration: Module 3's standalone `main.dart` (role choice → fake client
/// picker or the single restaurant) is replaced by TableGo's login.  These
/// widgets are the module's entry points in the TableGo navigation; they read
/// the logged-in user (`authProvider`) and pass the ids to Module 3's screens,
/// which are unchanged StatefulWidgets:
///
/// * [ReservationsRestaurantTab] — restaurant account: Demandes, Affluence IA,
///   Événements (`EcranAccueilRestaurant`) for its own restaurant;
/// * [ReserverTableTab] — client, inside a restaurant's page: upcoming events
///   (read-only) + its reservations at that restaurant + « Réserver »;
/// * [MesReservationsScreen] — client « Activité »: all its reservations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/current_restaurant.dart';
import '../../auth/providers/auth_provider.dart';
import '../database/evenements_repository.dart';
import '../models/evenement.dart';
import '../utils/aide_dates.dart';
import '../widgets/etat_vide.dart';
import 'client/ecran_mes_reservations.dart';
import 'restaurant/ecran_accueil_restaurant.dart';

/// Restaurant side: Module 3's home for the logged-in restaurant.
class ReservationsRestaurantTab extends ConsumerWidget {
  const ReservationsRestaurantTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(currentRestaurantIdProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EtatVide(
            icone: Icons.error_outline,
            titre: 'Une erreur est survenue',
            message: '$e',
          ),
          data: (restaurantId) => restaurantId == null
              ? const EtatVide(
                  icone: Icons.storefront_outlined,
                  titre: 'Aucun restaurant',
                  message: 'Ce compte n\'a pas de profil restaurant.',
                )
              : EcranAccueilRestaurant(restaurantId: restaurantId),
        );
  }
}

/// Client side, for one restaurant: its upcoming events and the client's
/// table reservations there, with the « Réserver » button.
class ReserverTableTab extends ConsumerWidget {
  const ReserverTableTab({super.key, required this.restaurantId});

  /// `restaurant_profiles.id`.
  final int restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientId = ref.watch(authProvider.select((s) => s.user?.id));
    if (clientId == null) return const SizedBox.shrink();
    return Column(
      children: [
        EvenementsAVenir(restaurantId: restaurantId),
        Expanded(
          child: EcranMesReservations(
              clientId: clientId, restaurantId: restaurantId),
        ),
      ],
    );
  }
}

/// Client « Activité »: all the client's reservations, every restaurant.
class MesReservationsScreen extends ConsumerWidget {
  const MesReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientId = ref.watch(authProvider.select((s) => s.user?.id));
    if (clientId == null) return const SizedBox.shrink();
    return EcranMesReservations(clientId: clientId);
  }
}

/// Read-only strip of the restaurant's upcoming events (client side).
class EvenementsAVenir extends StatelessWidget {
  const EvenementsAVenir({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Evenement>>(
      future: EvenementsRepository.instance
          .evenements(restaurantId, aVenirSeulement: true),
      builder: (context, snap) {
        final evenements = snap.data ?? const <Evenement>[];
        if (evenements.isEmpty) return const SizedBox.shrink();
        return SafeArea(
          bottom: false,
          child: SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              itemCount: evenements.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final e = evenements[i];
                return SizedBox(
                  width: 230,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.titre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${Evenement.libellesTypes[e.type] ?? e.type} · '
                            '${AideDates.formaterDateLongue(e.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const Spacer(),
                          Text('${e.placesRestantes} places restantes',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
