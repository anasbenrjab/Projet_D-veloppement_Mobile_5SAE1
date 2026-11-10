import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/gaspillage_db.dart';
import '../models/ingredient.dart';
import '../models/perte.dart';
import '../outils.dart';
import '../session.dart' as session;
import '../widgets/badge_peremption.dart';

class IngredientsPage extends StatefulWidget {
  const IngredientsPage({super.key});

  @override
  State<IngredientsPage> createState() => _IngredientsPageState();
}

class _IngredientsPageState extends State<IngredientsPage> {
  GaspillageDb dbHelper = GaspillageDb();
  late Future<List<Ingredient>> futureIngredients;
  String recherche = '';

  @override
  void initState() {
    super.initState();
    futureIngredients = dbHelper.getIngredients(session.restaurantId);
  }

  // relire le stock dans la base (le FutureBuilder va se reconstruire)
  void chargerIngredients() {
    setState(() {
      futureIngredients = dbHelper.getIngredients(session.restaurantId);
    });
  }

  void ouvrirFormulaire(Ingredient? i) async {
    var res =
        await Navigator.pushNamed(context, '/ajoutIngredient', arguments: i);
    if (res == true) chargerIngredients();
  }

  void supprimer(Ingredient i) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer ${i.nom} du stock ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // fermer la fenetre
              await dbHelper.deleteIngredient(i.id!);
              chargerIngredients();
            },
            child: const Text('Supprimer', style: TextStyle(color: rouge)),
          ),
        ],
      ),
    );
  }

  // jeter = enregistrer la perte dans le journal + retirer du stock
  void jeter(Ingredient i) {
    String raison = i.estPerime() ? 'Périmé' : 'Abîmé';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Jeter ${i.nom}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${nombre(i.quantite)} ${i.unite} = ${virgule(i.valeurStock(), 3)} TND perdus'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: raison,
                decoration: const InputDecoration(labelText: 'Raison'),
                items: Perte.raisons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  setStateDialog(() {
                    raison = v!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await dbHelper.jeterIngredient(i, raison);
                chargerIngredients();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(
                    content: Text('Ajouté au journal de gaspillage')));
              },
              child: const Text('Jeter', style: TextStyle(color: rouge)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Ingredient>>(
      future: futureIngredients,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<Ingredient> tous = snapshot.data!;
        List<Ingredient> ingredients = tous
            .where((i) => i.nom.toLowerCase().contains(recherche.toLowerCase()))
            .toList();

        int nbPerimes = tous.where((i) => i.estPerime()).length;
        int nbBientot = tous.where((i) => i.expireBientot()).length;
        double valeur = 0;
        for (Ingredient i in tous) {
          valeur = valeur + i.valeurStock();
        }

        return Scaffold(
          body: Column(
            children: [
              // alerte avant l'expiration
              if (nbPerimes > 0 || nbBientot > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: nbPerimes > 0 ? rougeClair : orangeClair,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: nbPerimes > 0 ? rouge : orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          [
                            if (nbPerimes > 0) '$nbPerimes périmé(s)',
                            if (nbBientot > 0)
                              '$nbBientot expire(nt) dans 3 jours ou moins',
                          ].join(' • '),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un ingrédient',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) {
                    setState(() {
                      recherche = v;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('${tous.length} ingrédients',
                        style: const TextStyle(color: gris)),
                    const Spacer(),
                    Text('Valeur du stock : ${virgule(valeur, 3)} TND',
                        style: const TextStyle(
                            color: gris, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ingredients.isEmpty
                    ? const Center(child: Text('Aucun ingrédient'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: ingredients.length,
                        itemBuilder: (context, i) =>
                            carteIngredient(ingredients[i]),
                      ),
              ),
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

  Widget carteIngredient(Ingredient i) {
    bool urgent = i.estPerime() || i.expireBientot();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: urgent ? orangeClair : vertClair,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.kitchen, color: urgent ? orange : vert),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.nom,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                      '${nombre(i.quantite)} ${i.unite} • ${virgule(i.cout, 3)} TND / ${i.unite}',
                      style: const TextStyle(color: gris)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      BadgePeremption(jours: i.joursAvantPeremption()),
                      const SizedBox(width: 6),
                      Text(dateFr(i.datePeremption),
                          style: const TextStyle(color: gris, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'modifier') ouvrirFormulaire(i);
                if (v == 'jeter') jeter(i);
                if (v == 'supprimer') supprimer(i);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                PopupMenuItem(
                    value: 'jeter', child: Text('Jeter (journal de gaspillage)')),
                PopupMenuItem(
                    value: 'supprimer',
                    child: Text('Supprimer', style: TextStyle(color: rouge))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
