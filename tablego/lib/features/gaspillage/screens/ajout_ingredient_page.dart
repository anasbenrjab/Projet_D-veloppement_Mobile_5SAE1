import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/gaspillage_db.dart';
import '../models/ingredient.dart';
import '../outils.dart';
import '../session.dart' as session;

class AjoutIngredientPage extends StatefulWidget {
  const AjoutIngredientPage({super.key});

  @override
  State<AjoutIngredientPage> createState() => _AjoutIngredientPageState();
}

class _AjoutIngredientPageState extends State<AjoutIngredientPage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController nomCtrl = TextEditingController();
  TextEditingController quantiteCtrl = TextEditingController();
  TextEditingController coutCtrl = TextEditingController();
  GaspillageDb dbHelper = GaspillageDb();

  Ingredient? ingredient; // si pas null on est en modification
  String unite = 'kg';
  DateTime datePeremption = DateTime.now().add(const Duration(days: 7));
  bool premiereFois = true;

  List<String> unites = ['kg', 'L', 'pièce'];

  @override
  void dispose() {
    nomCtrl.dispose();
    quantiteCtrl.dispose();
    coutCtrl.dispose();
    super.dispose();
  }

  void choisirDate() async {
    DateTime? d = await showDatePicker(
      context: context,
      initialDate: datePeremption,
      // on peut saisir une date passee (produit deja perime dans le stock)
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d != null) {
      setState(() {
        datePeremption = d;
      });
    }
  }

  // "2,5" -> 2.5
  double lireNombre(String texte) {
    return double.parse(texte.trim().replaceAll(',', '.'));
  }

  String? validerNombre(String? v) {
    double? n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
    if (n == null) return 'Nombre invalide';
    if (n < 0) return 'Pas de nombre négatif';
    return null;
  }

  void enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    Ingredient i = Ingredient(
      id: ingredient?.id,
      restaurantId: session.restaurantId,
      nom: nomCtrl.text.trim(),
      quantite: lireNombre(quantiteCtrl.text),
      unite: unite,
      cout: lireNombre(coutCtrl.text),
      datePeremption: formatDate(datePeremption),
    );

    if (ingredient == null) {
      await dbHelper.insertIngredient(i);
    } else {
      await dbHelper.updateIngredient(i);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // bouton pour choisir l'unite (orange = choisi)
  Widget boutonUnite(String valeur) {
    bool choisi = unite == valeur;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: choisi ? orange : Colors.white,
            foregroundColor: choisi ? Colors.white : brun,
          ),
          onPressed: () {
            setState(() {
              unite = valeur;
            });
          },
          child: Text(valeur),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // on recupere l'ingredient envoye avec pushNamed (une seule fois)
    if (premiereFois) {
      ingredient = ModalRoute.of(context)!.settings.arguments as Ingredient?;
      if (ingredient != null) {
        nomCtrl.text = ingredient!.nom;
        quantiteCtrl.text = nombre(ingredient!.quantite);
        coutCtrl.text = nombre(ingredient!.cout);
        unite = ingredient!.unite;
        datePeremption = DateTime.parse(ingredient!.datePeremption);
      }
      premiereFois = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            ingredient == null ? 'Nouvel ingrédient' : 'Modifier ingrédient'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nomCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom',
                hintText: 'ex: Tomate',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Nom obligatoire';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Unité'),
            const SizedBox(height: 8),
            Row(
              children: unites.map((u) => boutonUnite(u)).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: quantiteCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quantité',
                suffixText: unite,
              ),
              validator: validerNombre,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: coutCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Coût',
                suffixText: 'TND / $unite',
              ),
              validator: validerNombre,
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.event_busy),
              title: const Text('Date de péremption'),
              subtitle: Text(dateFr(formatDate(datePeremption))),
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
