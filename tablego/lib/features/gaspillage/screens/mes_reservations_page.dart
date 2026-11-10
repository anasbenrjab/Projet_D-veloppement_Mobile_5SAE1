import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/gaspillage_db.dart';
import '../models/reservation_offre.dart';
import '../outils.dart';
import '../session.dart' as session;

class MesReservationsPage extends StatefulWidget {
  const MesReservationsPage({super.key});

  @override
  State<MesReservationsPage> createState() => _MesReservationsPageState();
}

class _MesReservationsPageState extends State<MesReservationsPage> {
  GaspillageDb dbHelper = GaspillageDb();
  late Future<List<ReservationOffre>> futureReservations;

  @override
  void initState() {
    super.initState();
    futureReservations = dbHelper.getReservationsClient(session.userId, session.restaurantId);
  }

  void chargerReservations() {
    setState(() {
      futureReservations = dbHelper.getReservationsClient(session.userId, session.restaurantId);
    });
  }

  // encore possible d'annuler : avant la fin de l'offre
  bool peutAnnuler(ReservationOffre r) {
    int j = joursRestants(r.dateOffre!);
    if (j != 0) return j > 0;
    DateTime now = DateTime.now();
    return now.hour * 60 + now.minute < minutes(r.heureFin!);
  }

  void annuler(ReservationOffre r) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: Text('Annuler ${r.quantite} x ${r.plat} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Non')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await dbHelper.annulerReservation(r);
              chargerReservations();
            },
            child: const Text('Oui, annuler', style: TextStyle(color: rouge)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReservationOffre>>(
      future: futureReservations,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<ReservationOffre> reservations = snapshot.data!;
        if (reservations.isEmpty) {
          return const Center(child: Text('Aucune réservation'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: reservations.length,
          itemBuilder: (context, i) {
            ReservationOffre r = reservations[i];
            bool enCours = peutAnnuler(r);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: enCours ? vertClair : grisClair,
                  child: Icon(Icons.shopping_bag_outlined,
                      color: enCours ? vert : gris),
                ),
                title: Text('${r.quantite} x ${r.plat}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${session.restaurantNom}\n${dateFr(r.dateOffre!)} • avant ${r.heureFin}'),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${virgule(r.total(), 3)} TND',
                        style: const TextStyle(
                            color: orange, fontWeight: FontWeight.bold)),
                    if (enCours)
                      InkWell(
                        onTap: () => annuler(r),
                        child: const Text('Annuler',
                            style: TextStyle(color: rouge)),
                      )
                    else
                      const Text('Terminée', style: TextStyle(color: gris)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
