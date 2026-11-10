import 'package:flutter/material.dart';
import '../api/recettes_api.dart';
import '../couleurs.dart';
import '../db/database_helper.dart';
import '../ia/prediction_gaspillage.dart';
import '../models/ingredient.dart';
import '../models/vente.dart';
import '../outils.dart';
import '../session.dart' as session;
import '../widgets/badge_ia.dart';

class IaPage extends StatefulWidget {
  const IaPage({super.key});

  @override
  State<IaPage> createState() => _IaPageState();
}

class _IaPageState extends State<IaPage> {
  DatabaseHelper dbHelper = DatabaseHelper();
  late Future<List<Vente>> futureVentes;
  late Future<List<Ingredient>> futureStock;
  bool demain = true; // prediction pour demain ou pour aujourd'hui

  @override
  void initState() {
    super.initState();
    charger();
  }

  void charger() {
    setState(() {
      futureVentes = dbHelper.getVentes(session.restaurantId);
      futureStock = dbHelper.getIngredients(session.restaurantId);
    });
  }

  // le restaurant saisit sa journee : l'IA apprend avec ces chiffres
  void saisirJournee(List<String> plats) {
    final formKey = GlobalKey<FormState>();
    TextEditingController platCtrl = TextEditingController(
        text: plats.isNotEmpty ? plats.first : '');
    TextEditingController prepCtrl = TextEditingController();
    TextEditingController venduCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ventes du jour'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: platCtrl,
                decoration: const InputDecoration(labelText: 'Plat'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Plat obligatoire' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: prepCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Portions préparées'),
                validator: (v) {
                  int? n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 0) return 'Nombre invalide';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: venduCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Portions vendues'),
                validator: (v) {
                  int? n = int.tryParse((v ?? '').trim());
                  int? p = int.tryParse(prepCtrl.text.trim());
                  if (n == null || n < 0) return 'Nombre invalide';
                  if (p != null && n > p) return 'Plus que préparées ?';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
              await dbHelper.insertVente(Vente(
                restaurantId: session.restaurantId,
                plat: platCtrl.text.trim(),
                preparees: int.parse(prepCtrl.text.trim()),
                vendues: int.parse(venduCtrl.text.trim()),
                date: formatDate(aujourdhui()),
              ));
              charger();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // API TheMealDB : plus d'idees sur internet pour un ingredient
  void ideesInternet(String ingredient) {
    String? anglais =
        RecettesApi.traduire(PredictionGaspillage.nettoyer(ingredient));
    if (anglais == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pas de recherche internet pour "$ingredient"')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Recettes avec : $ingredient',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, String>>>(
                future: RecettesApi.chercher(anglais),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Pas de connexion internet'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  List<Map<String, String>> recettes = snapshot.data!;
                  if (recettes.isEmpty) {
                    return const Center(child: Text('Aucune recette trouvée'));
                  }
                  return ListView.builder(
                    itemCount: recettes.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          '${recettes[i]['photo']}/preview',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.restaurant, size: 40),
                        ),
                      ),
                      title: Text(recettes[i]['nom']!),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        titre('Quantité à préparer', Icons.insights),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Aujourd\'hui'),
                selected: !demain,
                selectedColor: orangeClair,
                onSelected: (_) => setState(() => demain = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Demain'),
                selected: demain,
                selectedColor: orangeClair,
                onSelected: (_) => setState(() => demain = true),
              ),
            ],
          ),
        ),
        FutureBuilder<List<Vente>>(
          future: futureVentes,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Erreur de chargement'));
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            List<Vente> ventes = snapshot.data!;
            List<String> plats = PredictionGaspillage.plats(ventes);
            DateTime jour = demain
                ? aujourdhui().add(const Duration(days: 1))
                : aujourdhui();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text('${nomJour(jour.weekday)} ${dateFr(formatDate(jour))}',
                      style: const TextStyle(color: gris)),
                ),
                for (String p in plats)
                  cartePrediction(
                      PredictionGaspillage.quantiteAPreparer(ventes, p, jour)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => saisirJournee(plats),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Saisir les ventes du jour'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        titre('Idées anti-gaspi', Icons.lightbulb_outline),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
              'Plats à proposer avec les ingrédients qui expirent dans 3 jours ou moins',
              style: TextStyle(color: gris)),
        ),
        FutureBuilder<List<Ingredient>>(
          future: futureStock,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Erreur de chargement'));
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            List<IdeeRecette> idees = PredictionGaspillage.idees(snapshot.data!);
            if (idees.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: Text('Aucun ingrédient urgent, rien à rattraper !')),
              );
            }
            return Column(
              children: [for (IdeeRecette i in idees) carteIdee(i)],
            );
          },
        ),
      ],
    );
  }

  Widget titre(String texte, IconData icone) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icone, color: orange),
          const SizedBox(width: 8),
          Text(texte,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          const BadgeIA(),
        ],
      ),
    );
  }

  Widget cartePrediction(Prediction p) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: orangeClair,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${p.quantite}',
                      style: const TextStyle(
                          color: orange,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const Text('portions',
                      style: TextStyle(color: orange, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.plat,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('D\'habitude : ${p.dejaPreparees} • jetées : ${virgule(p.moyenneRestes, 1)} / jour',
                      style: const TextStyle(color: gris, fontSize: 13)),
                  if (p.economie() > 0)
                    Text('${p.economie()} portion(s) de moins à préparer',
                        style: const TextStyle(
                            color: vert, fontWeight: FontWeight.bold)),
                  Text(p.explication,
                      style: const TextStyle(color: gris, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget etiquette(String texte, Color fond, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texte, style: TextStyle(color: couleur, fontSize: 12)),
    );
  }

  Widget carteIdee(IdeeRecette i) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_menu, color: orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(i.nom,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Text('${i.urgents.length} urgent(s)',
                    style: const TextStyle(color: orange)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (String u in i.urgents) etiquette(u, orangeClair, orange),
                for (String s in i.enStock) etiquette(s, vertClair, vert),
                for (String m in i.manquants)
                  etiquette('$m (à acheter)', grisClair, gris),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => ideesInternet(i.urgents.first),
                icon: const Icon(Icons.public, size: 18),
                label: const Text('Plus d\'idées sur internet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
