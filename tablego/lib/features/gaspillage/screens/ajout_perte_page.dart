import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/gaspillage_db.dart';
import '../models/perte.dart';
import '../outils.dart';
import '../session.dart' as session;

class AjoutPertePage extends StatefulWidget {
  const AjoutPertePage({super.key});

  @override
  State<AjoutPertePage> createState() => _AjoutPertePageState();
}

class _AjoutPertePageState extends State<AjoutPertePage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController produitCtrl = TextEditingController();
  TextEditingController quantiteCtrl = TextEditingController();
  TextEditingController coutCtrl = TextEditingController();
  GaspillageDb dbHelper = GaspillageDb();

  Perte? perte; // si pas null on est en modification
  String unite = 'kg';
  String raison = 'Surproduction';
  DateTime date = DateTime.now();
  bool premiereFois = true;

  List<String> unites = ['kg', 'L', 'pièce'];

  @override
  void dispose() {
    produitCtrl.dispose();
    quantiteCtrl.dispose();
    coutCtrl.dispose();
    super.dispose();
  }

  void choisirDate() async {
    DateTime? d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(), // une perte ne peut pas etre dans le futur
    );
    if (d != null) {
      setState(() {
        date = d;
      });
    }
  }

  double lireNombre(String texte) {
    return double.parse(texte.trim().replaceAll(',', '.'));
  }

  void enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    Perte p = Perte(
      id: perte?.id,
      restaurantId: session.restaurantId,
      produit: produitCtrl.text.trim(),
      quantite: lireNombre(quantiteCtrl.text),
      unite: unite,
      raison: raison,
      cout: lireNombre(coutCtrl.text),
      date: formatDate(date),
    );

    if (perte == null) {
      await dbHelper.insertPerte(p);
    } else {
      await dbHelper.updatePerte(p);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (premiereFois) {
      perte = ModalRoute.of(context)!.settings.arguments as Perte?;
      if (perte != null) {
        produitCtrl.text = perte!.produit;
        quantiteCtrl.text = nombre(perte!.quantite);
        coutCtrl.text = nombre(perte!.cout);
        unite = perte!.unite;
        raison = perte!.raison;
        date = DateTime.parse(perte!.date);
      }
      premiereFois = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(perte == null ? 'Nouvelle perte' : 'Modifier perte'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: produitCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Produit',
                hintText: 'ex: Couscous, Pain, Tomate',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Produit obligatoire';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: quantiteCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantité'),
                    validator: (v) {
                      double? n =
                          double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                      if (n == null || n <= 0) return 'Quantité invalide';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: unite,
                    decoration: const InputDecoration(labelText: 'Unité'),
                    items: unites
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        unite = v!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Raison'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Perte.raisons.map((r) {
                return ChoiceChip(
                  label: Text(r),
                  selected: raison == r,
                  selectedColor: orangeClair,
                  onSelected: (_) {
                    setState(() {
                      raison = r;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: coutCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Coût total',
                suffixText: 'TND',
              ),
              validator: (v) {
                double? n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                if (n == null || n < 0) return 'Coût invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(dateFr(formatDate(date))),
              onTap: choisirDate,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: enregistrer,
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
