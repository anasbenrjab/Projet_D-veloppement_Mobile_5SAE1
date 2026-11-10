import 'package:flutter/material.dart';
import '../api/traduction_api.dart';
import '../couleurs.dart';
import '../db/avis_promotions_db.dart';
import '../ia/analyse_avis.dart';
import '../models/avis.dart';
import '../outils.dart';
import '../session.dart' as session;
import '../widgets/badge_ia.dart';

class AvisPage extends StatefulWidget {
  const AvisPage({super.key});

  @override
  State<AvisPage> createState() => _AvisPageState();
}

class _AvisPageState extends State<AvisPage> {
  AvisPromotionsDb dbHelper = AvisPromotionsDb();
  late Future<List<Avis>> futureAvis;
  List<Avis> listeAvis = [];
  Avis? monAvis;
  String filtre = 'tous';
  TextEditingController reponseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    futureAvis = dbHelper.getAvis(session.restaurantId);
  }

  @override
  void dispose() {
    reponseCtrl.dispose();
    super.dispose();
  }

  // relire les avis dans la base (le FutureBuilder va se reconstruire)
  void chargerAvis() {
    setState(() {
      futureAvis = dbHelper.getAvis(session.restaurantId);
    });
  }

  // l'avis du client connecte (null s'il n'a pas encore donne d'avis)
  Avis? trouverMonAvis() {
    if (session.role != 'client') return null;
    for (Avis a in listeAvis) {
      if (a.clientId == session.userId) return a;
    }
    return null;
  }

  // les avis a afficher selon le role et le filtre
  List<Avis> avisAffiches() {
    List<Avis> res = [];
    for (Avis a in listeAvis) {
      if (session.role == 'client' && a.spam == 1 && a.clientId != session.userId) {
        continue; // le client ne voit pas les spams
      }
      if (filtre != 'tous' && a.sentiment != filtre) continue;
      res.add(a);
    }
    return res;
  }

  double moyenne() {
    List<Avis> l = listeAvis.where((a) => a.spam == 0).toList();
    if (l.isEmpty) return 0;
    int total = 0;
    for (Avis a in l) {
      total += a.note;
    }
    return total / l.length;
  }

  int compter(String s) {
    return listeAvis.where((a) => a.spam == 0 && a.sentiment == s).length;
  }

  void ouvrirFormulaire() async {
    var res = await Navigator.pushNamed(context, '/ajoutAvis', arguments: monAvis);
    if (res == true) chargerAvis();
  }

  void supprimer(Avis a) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous supprimer cet avis ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // fermer la fenetre
              await dbHelper.deleteAvis(a.id!);
              chargerAvis();
            },
            child: const Text('Supprimer', style: TextStyle(color: rouge)),
          ),
        ],
      ),
    );
  }

  void repondre(Avis a) {
    reponseCtrl.text = a.reponse ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Répondre à ${a.clientNom}'),
        content: TextField(
          controller: reponseCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Votre réponse...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              String texte = reponseCtrl.text.trim();
              if (AnalyseAvis.estOffensant(texte)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Réponse refusée : mots offensants')));
                return;
              }
              Navigator.pop(context); // fermer la fenetre
              // reponse vide = on supprime la reponse
              await dbHelper.repondre(a.id!, texte.isEmpty ? null : texte);
              chargerAvis();
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  // traduction de l'avis avec l'API externe (il faut internet)
  void traduire(Avis a) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Traduction en anglais'),
        content: FutureBuilder<String>(
          future: TraductionApi.traduire(a.commentaire),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                  'Connexion impossible. Vérifiez votre réseau et réessayez.');
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Text(snapshot.data!);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer')),
        ],
      ),
    );
  }

  Color couleurSentiment(String s) {
    if (s == 'positif') return vert;
    if (s == 'negatif') return rouge;
    return gris;
  }

  Color fondSentiment(String s) {
    if (s == 'positif') return vertClair;
    if (s == 'negatif') return rougeClair;
    return grisClair;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Avis>>(
      future: futureAvis,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        listeAvis = snapshot.data!;
        monAvis = trouverMonAvis();
        List<Avis> avis = avisAffiches();

        return Scaffold(
          body: Column(
            children: [
              resume(),
              // filtre par sentiment
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Row(
                  children: [
                    boutonFiltre('tous', 'Tous'),
                    boutonFiltre('positif', 'Positifs'),
                    boutonFiltre('neutre', 'Neutres'),
                    boutonFiltre('negatif', 'Négatifs'),
                  ],
                ),
              ),
              Expanded(
                child: avis.isEmpty
                    ? const Center(child: Text('Aucun avis'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: avis.length,
                        itemBuilder: (context, i) => carteAvis(avis[i]),
                      ),
              ),
            ],
          ),
          floatingActionButton: session.role == 'client'
              ? FloatingActionButton.extended(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  onPressed: ouvrirFormulaire,
                  icon: Icon(monAvis == null ? Icons.add : Icons.edit),
                  label: Text(
                      monAvis == null ? 'Donner mon avis' : 'Modifier mon avis'),
                )
              : null,
        );
      },
    );
  }

  Widget boutonFiltre(String valeur, String texte) {
    bool choisi = filtre == valeur;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: choisi ? orange : Colors.white,
            foregroundColor: choisi ? Colors.white : brun,
            padding: EdgeInsets.zero,
          ),
          onPressed: () {
            setState(() {
              filtre = valeur;
            });
          },
          child: Text(texte),
        ),
      ),
    );
  }

  Widget resume() {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                Text(virgule(moyenne(), 1),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                const Icon(Icons.star, color: jaune),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('Analyse des avis',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      BadgeIA(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Positifs : ${compter('positif')}',
                      style: const TextStyle(color: vert)),
                  Text('Neutres : ${compter('neutre')}',
                      style: const TextStyle(color: gris)),
                  Text('Négatifs : ${compter('negatif')}',
                      style: const TextStyle(color: rouge)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget carteAvis(Avis a) {
    bool estMoi = session.role == 'client' && a.clientId == session.userId;
    bool estRestaurant = session.role == 'restaurant';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: orangeClair,
                  child: Text(a.clientNom[0],
                      style: const TextStyle(color: orange)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.clientNom,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(dateFr(a.date), style: const TextStyle(color: gris, fontSize: 12)),
                    ],
                  ),
                ),
                // etoiles
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(i < a.note ? Icons.star : Icons.star_border,
                        color: jaune, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('« ${a.commentaire} »'),
            const SizedBox(height: 8),
            Row(
              children: [
                // resultat de l'IA
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: fondSentiment(a.sentiment),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  // etincelle = resultat de l'IA (charte figma)
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 14, color: couleurSentiment(a.sentiment)),
                      const SizedBox(width: 4),
                      Text(texteSentiment(a.sentiment),
                          style: TextStyle(
                              color: couleurSentiment(a.sentiment),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (a.spam == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: rougeClair,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(estMoi ? 'En vérification' : 'Spam',
                        style: const TextStyle(
                            color: rouge, fontWeight: FontWeight.bold)),
                  ),
                const Spacer(),
                IconButton(
                    onPressed: () => traduire(a),
                    icon: const Icon(Icons.translate, color: gris)),
                if (estMoi)
                  IconButton(
                      onPressed: ouvrirFormulaire,
                      icon: const Icon(Icons.edit, color: gris)),
                if (estMoi)
                  IconButton(
                      onPressed: () => supprimer(a),
                      icon: const Icon(Icons.delete, color: rouge)),
              ],
            ),
            if (a.reponse != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: creme,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Réponse du restaurant :\n${a.reponse}'),
              ),
            // actions du restaurant
            if (estRestaurant && a.spam == 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => repondre(a),
                  child: Text(a.reponse == null ? 'Répondre' : 'Modifier la réponse'),
                ),
              ),
            if (estRestaurant && a.spam == 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      await dbHelper.publierAvis(a.id!);
                      chargerAvis();
                    },
                    child: const Text('Pas un spam'),
                  ),
                  TextButton(
                    onPressed: () => supprimer(a),
                    child: const Text('Supprimer', style: TextStyle(color: rouge)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
