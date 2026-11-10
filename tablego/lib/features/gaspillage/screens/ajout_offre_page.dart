import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/gaspillage_db.dart';
import '../ia/prediction_gaspillage.dart';
import '../models/offre.dart';
import '../outils.dart';
import '../session.dart' as session;
import '../widgets/badge_ia.dart';

class AjoutOffrePage extends StatefulWidget {
  const AjoutOffrePage({super.key});

  @override
  State<AjoutOffrePage> createState() => _AjoutOffrePageState();
}

class _AjoutOffrePageState extends State<AjoutOffrePage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController platCtrl = TextEditingController();
  TextEditingController prixInitialCtrl = TextEditingController();
  TextEditingController prixReduitCtrl = TextEditingController();
  TextEditingController quantiteCtrl = TextEditingController();
  GaspillageDb dbHelper = GaspillageDb();

  Offre? offre; // si pas null on est en modification
  String heureFin = session.heureFermeture;
  PrixSuggere? suggestion; // resultat de l'IA
  bool premiereFois = true;

  @override
  void dispose() {
    platCtrl.dispose();
    prixInitialCtrl.dispose();
    prixReduitCtrl.dispose();
    quantiteCtrl.dispose();
    super.dispose();
  }

  void choisirHeure() async {
    TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: minutes(heureFin) ~/ 60, minute: minutes(heureFin) % 60),
    );
    if (t != null) {
      setState(() {
        heureFin = formatHeure(t.hour, t.minute);
      });
    }
  }

  double? lireNombre(String texte) {
    return double.tryParse(texte.trim().replaceAll(',', '.'));
  }

  // minutes entre maintenant et la fin de l'offre
  int minutesAvantFin() {
    DateTime now = DateTime.now();
    int m = minutes(heureFin) - (now.hour * 60 + now.minute);
    if (m < 0) m = 0;
    return m;
  }

  // l'IA propose un prix juste
  void suggererPrix() {
    double? prix = lireNombre(prixInitialCtrl.text);
    int? qte = int.tryParse(quantiteCtrl.text.trim());
    if (prix == null || prix <= 0 || qte == null || qte <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Saisissez d\'abord le prix initial et la quantité')));
      return;
    }
    PrixSuggere s =
        PredictionGaspillage.prixSuggere(prix, minutesAvantFin(), qte);
    setState(() {
      suggestion = s;
      prixReduitCtrl.text = virgule(s.prix, 1);
    });
  }

  void enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    // une nouvelle offre doit se terminer apres maintenant
    if (offre == null && minutesAvantFin() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('L\'heure de fin est déjà passée')));
      return;
    }

    Offre o = Offre(
      id: offre?.id,
      restaurantId: session.restaurantId,
      plat: platCtrl.text.trim(),
      prixInitial: lireNombre(prixInitialCtrl.text)!,
      prixReduit: lireNombre(prixReduitCtrl.text)!,
      quantite: int.parse(quantiteCtrl.text.trim()),
      date: offre?.date ?? formatDate(aujourdhui()),
      heureFin: heureFin,
    );

    if (offre == null) {
      await dbHelper.insertOffre(o);
    } else {
      await dbHelper.updateOffre(o);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (premiereFois) {
      offre = ModalRoute.of(context)!.settings.arguments as Offre?;
      if (offre != null) {
        platCtrl.text = offre!.plat;
        prixInitialCtrl.text = nombre(offre!.prixInitial);
        prixReduitCtrl.text = nombre(offre!.prixReduit);
        quantiteCtrl.text = offre!.quantite.toString();
        heureFin = offre!.heureFin;
      }
      premiereFois = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(offre == null ? 'Nouvelle offre' : 'Modifier offre'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: platCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Plat',
                hintText: 'ex: Couscous au poulet',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Plat obligatoire';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: prixInitialCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Prix initial', suffixText: 'TND'),
                    validator: (v) {
                      double? n = lireNombre(v ?? '');
                      if (n == null || n <= 0) return 'Prix invalide';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: quantiteCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Portions', suffixText: 'pièce(s)'),
                    validator: (v) {
                      int? n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 0) return 'Nombre invalide';
                      if (offre == null && n == 0) return 'Au moins 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.schedule),
              title: const Text('Fin de l\'offre'),
              subtitle: Text('Aujourd\'hui à $heureFin'),
              onTap: choisirHeure,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: prixReduitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Prix réduit', suffixText: 'TND'),
              validator: (v) {
                double? n = lireNombre(v ?? '');
                double? initial = lireNombre(prixInitialCtrl.text);
                if (n == null || n <= 0) return 'Prix invalide';
                if (initial != null && n >= initial) {
                  return 'Doit être moins cher que le prix initial';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            // fonction IA : prix de reduction juste
            OutlinedButton.icon(
              onPressed: suggererPrix,
              icon: const Icon(Icons.auto_awesome, color: orange),
              label: const Text('Suggérer un prix juste'),
            ),
            if (suggestion != null) carteSuggestion(suggestion!),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: enregistrer,
                child: const Text('Publier'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget carteSuggestion(PrixSuggere s) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: orangeClair,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${virgule(s.prix, 3)} TND (-${s.pourcentage} %)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              const BadgeIA(),
            ],
          ),
          const SizedBox(height: 4),
          for (String r in s.raisons)
            Text('• $r', style: const TextStyle(color: brun)),
        ],
      ),
    );
  }
}
