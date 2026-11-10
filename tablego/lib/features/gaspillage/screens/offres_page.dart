import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/gaspillage_db.dart';
import '../models/offre.dart';
import '../outils.dart';
import '../session.dart' as session;

class OffresPage extends StatefulWidget {
  const OffresPage({super.key});

  @override
  State<OffresPage> createState() => _OffresPageState();
}

class _OffresPageState extends State<OffresPage> {
  GaspillageDb dbHelper = GaspillageDb();
  late Future<List<Offre>> futureOffres;
  Map<int, int> reservees = {}; // offreId -> portions reservees

  @override
  void initState() {
    super.initState();
    futureOffres = lire();
  }

  // on lit les offres et aussi le nombre de portions reservees
  Future<List<Offre>> lire() async {
    reservees = await dbHelper.getPortionsReservees(session.restaurantId);
    return await dbHelper.getOffres(session.restaurantId);
  }

  void chargerOffres() {
    setState(() {
      futureOffres = lire();
    });
  }

  void ouvrirFormulaire(Offre? o) async {
    var res = await Navigator.pushNamed(context, '/ajoutOffre', arguments: o);
    if (res == true) chargerOffres();
  }

  void supprimer(Offre o) {
    int nb = reservees[o.id] ?? 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text(nb > 0
            ? 'Supprimer l\'offre ${o.plat} ? $nb portion(s) déjà réservée(s) seront annulées.'
            : 'Supprimer l\'offre ${o.plat} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await dbHelper.deleteOffre(o.id!);
              chargerOffres();
            },
            child: const Text('Supprimer', style: TextStyle(color: rouge)),
          ),
        ],
      ),
    );
  }

  // le client choisit le nombre de portions
  void reserver(Offre o) {
    int quantite = 1;
    int max = o.quantite < 5 ? o.quantite : 5; // 5 portions max par client

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Réserver ${o.plat}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: quantite > 1
                        ? () => setStateDialog(() => quantite--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$quantite',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    onPressed: quantite < max
                        ? () => setStateDialog(() => quantite++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              Text('Total : ${virgule(quantite * o.prixReduit, 3)} TND',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('À récupérer avant ${o.heureFin} au restaurant',
                  style: const TextStyle(color: gris)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44)), // pas pleine largeur
              onPressed: () async {
                Navigator.pop(context);
                bool ok = await dbHelper.reserverOffre(
                    o, quantite, session.userId, session.userNom);
                chargerOffres();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Réservé ! À récupérer avant ${o.heureFin}'
                      : 'Désolé, il ne reste plus assez de portions'),
                ));
              },
              child: const Text('Réserver'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool estRestaurant = session.role == 'restaurant';

    return FutureBuilder<List<Offre>>(
      future: futureOffres,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<Offre> offres = snapshot.data!;
        // le client voit seulement les offres encore disponibles
        if (!estRestaurant) {
          offres = offres.where((o) => o.estDisponible()).toList();
        }

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => chargerOffres(),
            child: offres.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      const Icon(Icons.eco_outlined, size: 60, color: gris),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(estRestaurant
                            ? 'Aucune offre. Publiez vos restes en fin de service !'
                            : 'Pas d\'offre anti-gaspi pour le moment'),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: offres.length,
                    itemBuilder: (context, i) => carteOffre(offres[i]),
                  ),
          ),
          floatingActionButton: estRestaurant
              ? FloatingActionButton(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  onPressed: () => ouvrirFormulaire(null),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Widget carteOffre(Offre o) {
    bool estRestaurant = session.role == 'restaurant';
    bool dispo = o.estDisponible();

    String etat = 'En cours';
    if (o.estTerminee()) {
      etat = 'Terminée';
    } else if (o.quantite == 0) {
      etat = 'Tout réservé';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 70,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dispo ? vert : grisClair,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('-${o.pourcentage()}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.plat,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (!estRestaurant)
                        Text(session.restaurantNom,
                            style: const TextStyle(color: gris)),
                      Row(
                        children: [
                          Text('${virgule(o.prixInitial, 3)} TND',
                              style: const TextStyle(
                                  color: gris,
                                  decoration: TextDecoration.lineThrough)),
                          const SizedBox(width: 8),
                          Text('${virgule(o.prixReduit, 3)} TND',
                              style: const TextStyle(
                                  color: orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: gris),
                const SizedBox(width: 4),
                Text(
                    estRestaurant
                        ? '${dateFr(o.date)} jusqu\'à ${o.heureFin}'
                        : 'Jusqu\'à ${o.heureFin}',
                    style: const TextStyle(color: gris)),
                const SizedBox(width: 12),
                const Icon(Icons.restaurant, size: 16, color: gris),
                const SizedBox(width: 4),
                Text('${o.quantite} restante(s)',
                    style: const TextStyle(color: gris)),
              ],
            ),
            if (estRestaurant)
              Row(
                children: [
                  Text(etat,
                      style: TextStyle(
                          color: dispo ? vert : gris,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('• ${reservees[o.id] ?? 0} réservée(s)',
                      style: const TextStyle(color: gris)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => ouvrirFormulaire(o),
                      icon: const Icon(Icons.edit, color: gris)),
                  IconButton(
                      onPressed: () => supprimer(o),
                      icon: const Icon(Icons.delete, color: rouge)),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        foregroundColor: Colors.white),
                    onPressed: () => reserver(o),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Réserver'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
