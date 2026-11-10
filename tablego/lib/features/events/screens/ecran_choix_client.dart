import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/client.dart';
import '../widgets/etat_vide.dart';
import 'client/ecran_mes_reservations.dart';

/// Choix du profil client de démonstration.
///
/// Comme il n'y a pas d'authentification, le client "se connecte" en
/// choisissant son nom dans la liste. Les profils ayant déjà fait un
/// no-show sont signalés : cela permettra de voir le score de risque
/// IA plus élevé lors de leur prochaine réservation.
class EcranChoixClient extends StatelessWidget {
  const EcranChoixClient({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qui êtes-vous ?')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: DatabaseHelper.instance.clientsAvecNoShows(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EtatVide(
              icone: Icons.error_outline,
              titre: 'Erreur de base de données',
              message: snapshot.error.toString(),
            );
          }
          final lignes = snapshot.data ?? const [];
          if (lignes.isEmpty) {
            return const EtatVide(
              icone: Icons.person_off,
              titre: 'Aucun client',
              message: 'La base de données ne contient aucun profil.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: lignes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ligne = lignes[index];
              final client = Client.fromMap(ligne);
              final nbNoShows = (ligne['nb_no_shows'] as int?) ?? 0;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepOrange.shade100,
                    child: Text(
                      client.nom.isNotEmpty ? client.nom[0] : '?',
                      style: TextStyle(
                        color: Colors.deepOrange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(client.nom),
                  subtitle: nbNoShows > 0
                      ? Text(
                          '$nbNoShows no-show(s) passé(s) — risque plus élevé',
                        )
                      : const Text('Profil sans incident'),
                  trailing: nbNoShows > 0
                      ? const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange)
                      : null,
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EcranMesReservations(clientId: client.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
