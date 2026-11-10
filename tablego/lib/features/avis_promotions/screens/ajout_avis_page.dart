import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/avis_promotions_db.dart';
import '../ia/analyse_avis.dart';
import '../models/avis.dart';
import '../outils.dart';
import '../session.dart' as session;
import '../widgets/badge_ia.dart';

class AjoutAvisPage extends StatefulWidget {
  const AjoutAvisPage({super.key});

  @override
  State<AjoutAvisPage> createState() => _AjoutAvisPageState();
}

class _AjoutAvisPageState extends State<AjoutAvisPage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController commentaireCtrl = TextEditingController();
  AvisPromotionsDb dbHelper = AvisPromotionsDb();

  Avis? avis; // si pas null on est en modification
  int note = 0;
  bool premiereFois = true;
  String sentimentDirect = '';

  @override
  void dispose() {
    commentaireCtrl.dispose();
    super.dispose();
  }

  // l'IA analyse pendant que l'utilisateur ecrit
  void analyser() {
    setState(() {
      if (commentaireCtrl.text.trim().isEmpty || note == 0) {
        sentimentDirect = '';
      } else {
        sentimentDirect = AnalyseAvis.sentiment(commentaireCtrl.text, note);
      }
    });
  }

  void enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    if (note == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisissez une note')));
      return;
    }

    String texte = commentaireCtrl.text.trim();

    // avis offensant -> on refuse
    if (AnalyseAvis.estOffensant(texte)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Avis refusé'),
          content: const Text(
              'Votre avis contient des mots offensants. Merci de le modifier.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    bool spam = AnalyseAvis.estSpam(texte);
    DateTime now = DateTime.now();
    String date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    Avis nouvel = Avis(
      id: avis?.id,
      restaurantId: session.restaurantId,
      clientId: session.userId,
      clientNom: session.userNom,
      note: note,
      commentaire: texte,
      date: date,
      reponse: avis?.reponse,
      sentiment: AnalyseAvis.sentiment(texte, note),
      spam: spam ? 1 : 0,
    );

    if (avis == null) {
      await dbHelper.insertAvis(nouvel);
    } else {
      await dbHelper.updateAvis(nouvel);
    }

    if (!mounted) return; // la page a peut-etre ete fermee pendant l'attente
    if (spam) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Avis envoyé, il sera vérifié par le restaurant')));
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    // on recupere l'avis envoye avec pushNamed (une seule fois)
    if (premiereFois) {
      avis = ModalRoute.of(context)!.settings.arguments as Avis?;
      if (avis != null) {
        note = avis!.note;
        commentaireCtrl.text = avis!.commentaire;
        sentimentDirect = AnalyseAvis.sentiment(avis!.commentaire, note);
      }
      premiereFois = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(avis == null ? 'Donner mon avis' : 'Modifier mon avis'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(session.restaurantNom,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Votre note', textAlign: TextAlign.center),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () {
                    note = i + 1;
                    analyser();
                  },
                  child: Icon(
                    i < note ? Icons.star : Icons.star_border,
                    color: jaune,
                    size: 44,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: commentaireCtrl,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                hintText: 'Racontez votre expérience...',
              ),
              onChanged: (v) => analyser(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Le commentaire est obligatoire';
                }
                if (v.trim().length < 5) {
                  return '5 caractères minimum';
                }
                return null;
              },
            ),
            if (sentimentDirect != '')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: orange),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const BadgeIA(),
                    const SizedBox(width: 8),
                    Text('Avis ${texteSentiment(sentimentDirect)}'),
                  ],
                ),
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
                child: Text(avis == null ? 'Publier' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
