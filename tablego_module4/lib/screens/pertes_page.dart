import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/database_helper.dart';
import '../models/perte.dart';
import '../outils.dart';
import '../session.dart' as session;

class PertesPage extends StatefulWidget {
  const PertesPage({super.key});

  @override
  State<PertesPage> createState() => _PertesPageState();
}

class _PertesPageState extends State<PertesPage> {
  DatabaseHelper dbHelper = DatabaseHelper();
  late Future<List<Perte>> futurePertes;
  int periode = 30; // 7 jours, 30 jours ou 0 = tout

  @override
  void initState() {
    super.initState();
    futurePertes = dbHelper.getPertes(session.restaurantId);
  }

  void chargerPertes() {
    setState(() {
      futurePertes = dbHelper.getPertes(session.restaurantId);
    });
  }

  void ouvrirFormulaire(Perte? p) async {
    var res = await Navigator.pushNamed(context, '/ajoutPerte', arguments: p);
    if (res == true) chargerPertes();
  }

  void supprimer(Perte p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer la perte "${p.produit}" du journal ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await dbHelper.deletePerte(p.id!);
              chargerPertes();
            },
            child: const Text('Supprimer', style: TextStyle(color: rouge)),
          ),
        ],
      ),
    );
  }

  IconData iconeRaison(String raison) {
    if (raison == 'Périmé') return Icons.event_busy;
    if (raison == 'Surproduction') return Icons.restaurant;
    if (raison == 'Abîmé') return Icons.broken_image_outlined;
    if (raison == 'Retour client') return Icons.undo;
    return Icons.help_outline;
  }

  Widget choixPeriode(int jours, String texte) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texte),
        selected: periode == jours,
        selectedColor: orangeClair,
        onSelected: (_) {
          setState(() {
            periode = jours;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Perte>>(
      future: futurePertes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // on garde seulement les pertes de la periode choisie
        List<Perte> pertes = snapshot.data!;
        if (periode > 0) {
          pertes =
              pertes.where((p) => joursRestants(p.date) > -periode).toList();
        }

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    choixPeriode(7, '7 jours'),
                    choixPeriode(30, '30 jours'),
                    choixPeriode(0, 'Tout'),
                  ],
                ),
              ),
              statistiques(pertes),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Journal',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              if (pertes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Aucune perte, bravo !')),
                ),
              for (Perte p in pertes) cartePerte(p),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: orange,
            foregroundColor: Colors.white,
            onPressed: () => ouvrirFormulaire(null),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  // statistiques deduites du journal
  Widget statistiques(List<Perte> pertes) {
    double total = 0;
    Map<String, double> parRaison = {};
    Map<String, double> parProduit = {};

    for (Perte p in pertes) {
      total = total + p.cout;
      parRaison[p.raison] = (parRaison[p.raison] ?? 0) + p.cout;
      parProduit[p.produit] = (parProduit[p.produit] ?? 0) + p.cout;
    }

    // produit qui a coute le plus cher
    String pire = '-';
    double max = 0;
    parProduit.forEach((produit, cout) {
      if (cout > max) {
        max = cout;
        pire = produit;
      }
    });

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: chiffre('${virgule(total, 3)} TND', 'Coût perdu',
                        rouge)),
                Expanded(
                    child: chiffre('${pertes.length}', 'Pertes', brun)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Le plus gaspillé : $pire',
                style: const TextStyle(color: gris)),
            const SizedBox(height: 12),
            const Text('Par raison',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (String r in Perte.raisons)
              if (parRaison[r] != null) barre(r, parRaison[r]!, total),
          ],
        ),
      ),
    );
  }

  Widget chiffre(String valeur, String texte, Color couleur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valeur,
            style: TextStyle(
                color: couleur, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(texte, style: const TextStyle(color: gris)),
      ],
    );
  }

  // barre horizontale simple (pas besoin de librairie de graphiques)
  Widget barre(String raison, double cout, double total) {
    double part = total == 0 ? 0 : cout / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(raison)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: part,
                minHeight: 10,
                color: orange,
                backgroundColor: grisClair,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text('${(part * 100).round()} %',
                textAlign: TextAlign.right,
                style: const TextStyle(color: gris)),
          ),
        ],
      ),
    );
  }

  Widget cartePerte(Perte p) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rougeClair,
          child: Icon(iconeRaison(p.raison), color: rouge),
        ),
        title: Text(p.produit,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${nombre(p.quantite)} ${p.unite} • ${p.raison}\n${dateFr(p.date)}'),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('-${virgule(p.cout, 3)}',
                style: const TextStyle(
                    color: rouge, fontWeight: FontWeight.bold)),
            const Text('TND', style: TextStyle(color: gris, fontSize: 12)),
          ],
        ),
        onTap: () => ouvrirFormulaire(p),
        onLongPress: () => supprimer(p),
      ),
    );
  }
}
