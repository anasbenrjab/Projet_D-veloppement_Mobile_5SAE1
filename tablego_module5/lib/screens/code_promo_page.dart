import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/database_helper.dart';
import '../models/promotion.dart';
import '../outils.dart';
import '../session.dart' as session;

// le client applique un code promo sur sa commande
// (le montant viendra du panier du module 2, ici on le tape pour tester)
class CodePromoPage extends StatefulWidget {
  const CodePromoPage({super.key});

  @override
  State<CodePromoPage> createState() => _CodePromoPageState();
}

class _CodePromoPageState extends State<CodePromoPage> {
  TextEditingController montantCtrl = TextEditingController(text: '50');
  TextEditingController codeCtrl = TextEditingController();
  DatabaseHelper dbHelper = DatabaseHelper();

  String message = '';
  bool valide = false;
  double reduction = 0;
  bool premiereFois = true;

  @override
  void dispose() {
    montantCtrl.dispose();
    codeCtrl.dispose();
    super.dispose();
  }

  // si on change le montant ou le code, il faut re-appliquer
  void effacer() {
    setState(() {
      valide = false;
      reduction = 0;
      message = '';
    });
  }

  void appliquer() async {
    double montant = double.tryParse(montantCtrl.text.replaceAll(',', '.')) ?? 0;
    String code = codeCtrl.text.trim().toUpperCase();

    Promotion? p = await dbHelper.getPromotionParCode(code);

    String msg;
    bool ok = false;
    double r = 0;

    if (code.isEmpty) {
      msg = 'Entrez un code';
    } else if (p == null || p.restaurantId != session.restaurantId) {
      msg = 'Code invalide';
    } else if (p.actif == 0) {
      msg = 'Ce code est désactivé';
    } else if (p.estExpiree()) {
      msg = 'Ce code a expiré';
    } else {
      r = p.calculerReduction(montant);
      msg = 'Code appliqué : ${p.texteReduction()}';
      ok = true;
    }

    if (!mounted) return;
    setState(() {
      message = msg;
      valide = ok;
      reduction = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    // si on vient d'une carte promo, le code est envoye avec pushNamed
    if (premiereFois) {
      String? codeRecu = ModalRoute.of(context)!.settings.arguments as String?;
      if (codeRecu != null) codeCtrl.text = codeRecu;
      premiereFois = false;
    }

    double montant = double.tryParse(montantCtrl.text.replaceAll(',', '.')) ?? 0;
    double total = montant - reduction;

    return Scaffold(
      appBar: AppBar(title: const Text('Code promo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: montantCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Montant de la commande',
              suffixText: 'TND',
            ),
            onChanged: (v) => effacer(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Code promo',
            ),
            onChanged: (v) => effacer(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
              ),
              onPressed: appliquer,
              child: const Text('Appliquer'),
            ),
          ),
          const SizedBox(height: 12),
          if (message != '')
            Text(message,
                style: TextStyle(
                    color: valide ? vert : rouge, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sous-total'),
                      Text('${virgule(montant, 3)} TND'),
                    ],
                  ),
                  if (valide)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Réduction', style: TextStyle(color: vert)),
                        Text('- ${virgule(reduction, 3)} TND',
                            style: const TextStyle(color: vert)),
                      ],
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${virgule(total, 3)} TND',
                          style: const TextStyle(
                              color: orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
