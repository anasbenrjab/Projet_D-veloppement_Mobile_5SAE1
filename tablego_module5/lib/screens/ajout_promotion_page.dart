import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/database_helper.dart';
import '../models/promotion.dart';
import '../outils.dart';
import '../session.dart' as session;

class AjoutPromotionPage extends StatefulWidget {
  const AjoutPromotionPage({super.key});

  @override
  State<AjoutPromotionPage> createState() => _AjoutPromotionPageState();
}

class _AjoutPromotionPageState extends State<AjoutPromotionPage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController titreCtrl = TextEditingController();
  TextEditingController valeurCtrl = TextEditingController();
  TextEditingController codeCtrl = TextEditingController();
  DatabaseHelper dbHelper = DatabaseHelper();

  Promotion? promo; // si pas null on est en modification
  String type = '%';
  DateTime dateFin = DateTime.now().add(const Duration(days: 30));
  bool premiereFois = true;

  @override
  void dispose() {
    titreCtrl.dispose();
    valeurCtrl.dispose();
    codeCtrl.dispose();
    super.dispose();
  }

  String formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void choisirDate() async {
    DateTime? d = await showDatePicker(
      context: context,
      initialDate: dateFin.isBefore(DateTime.now()) ? DateTime.now() : dateFin,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (d != null) {
      setState(() {
        dateFin = d;
      });
    }
  }

  void enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    String code = codeCtrl.text.trim().toUpperCase();

    // verifier que le code n'existe pas deja
    Promotion? existe = await dbHelper.getPromotionParCode(code);
    if (existe != null && existe.id != promo?.id) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce code existe déjà')));
      return;
    }

    Promotion p = Promotion(
      id: promo?.id,
      restaurantId: session.restaurantId,
      titre: titreCtrl.text.trim(),
      type: type,
      valeur: double.parse(valeurCtrl.text.replaceAll(',', '.')),
      code: code,
      dateFin: formatDate(dateFin),
      actif: promo?.actif ?? 1,
    );

    if (promo == null) {
      await dbHelper.insertPromotion(p);
    } else {
      await dbHelper.updatePromotion(p);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // bouton pour choisir le type (orange = choisi)
  Widget boutonType(String valeur, String texte) {
    bool choisi = type == valeur;
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
              type = valeur;
            });
          },
          child: Text(texte),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // on recupere la promotion envoyee avec pushNamed (une seule fois)
    if (premiereFois) {
      promo = ModalRoute.of(context)!.settings.arguments as Promotion?;
      if (promo != null) {
        titreCtrl.text = promo!.titre;
        valeurCtrl.text = nombre(promo!.valeur);
        codeCtrl.text = promo!.code;
        type = promo!.type;
        dateFin = DateTime.parse(promo!.dateFin);
      }
      premiereFois = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(promo == null ? 'Nouvelle promotion' : 'Modifier promotion'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: titreCtrl,
              decoration: const InputDecoration(
                labelText: 'Titre',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Titre obligatoire';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Type de réduction'),
            const SizedBox(height: 8),
            Row(
              children: [
                boutonType('%', 'Pourcentage %'),
                boutonType('TND', 'Montant TND'),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: valeurCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Valeur',
                suffixText: type,
              ),
              validator: (v) {
                double? n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Valeur invalide';
                if (type == '%' && n > 100) return 'Maximum 100 %';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Code promo',
                hintText: 'ex: SOIREE20',
              ),
              validator: (v) {
                if (v == null || v.trim().length < 4) {
                  return 'Le code doit avoir au moins 4 caractères';
                }
                if (v.contains(' ')) return 'Pas d\'espace dans le code';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date de fin'),
              subtitle: Text(dateFr(formatDate(dateFin))),
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
