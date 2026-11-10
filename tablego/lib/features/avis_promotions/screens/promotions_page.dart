import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/avis_promotions_db.dart';
import '../models/promotion.dart';
import '../outils.dart';
import '../session.dart' as session;

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  AvisPromotionsDb dbHelper = AvisPromotionsDb();
  late Future<List<Promotion>> futurePromotions;

  @override
  void initState() {
    super.initState();
    futurePromotions = dbHelper.getPromotions(session.restaurantId);
  }

  // relire les promotions dans la base (le FutureBuilder va se reconstruire)
  void chargerPromotions() {
    setState(() {
      futurePromotions = dbHelper.getPromotions(session.restaurantId);
    });
  }

  void ouvrirFormulaire(Promotion? p) async {
    var res = await Navigator.pushNamed(context, '/ajoutPromotion', arguments: p);
    if (res == true) chargerPromotions();
  }

  void supprimer(Promotion p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer la promotion ${p.code} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // fermer la fenetre
              await dbHelper.deletePromotion(p.id!);
              chargerPromotions();
            },
            child: const Text('Supprimer', style: TextStyle(color: rouge)),
          ),
        ],
      ),
    );
  }

  void activerDesactiver(Promotion p) async {
    if (p.actif == 1) {
      p.actif = 0;
    } else {
      p.actif = 1;
    }
    await dbHelper.updatePromotion(p);
    chargerPromotions();
  }

  @override
  Widget build(BuildContext context) {
    bool estRestaurant = session.role == 'restaurant';

    return FutureBuilder<List<Promotion>>(
      future: futurePromotions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<Promotion> promotions = snapshot.data!;
        // le client voit seulement les promos actives et pas expirees
        if (!estRestaurant) {
          promotions =
              promotions.where((p) => p.actif == 1 && !p.estExpiree()).toList();
        }

        return Scaffold(
          body: Column(
            children: [
              if (!estRestaurant)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/codePromo'),
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: const Text("J'ai un code promo"),
                    ),
                  ),
                ),
              Expanded(
                child: promotions.isEmpty
                    ? const Center(child: Text('Aucune promotion'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: promotions.length,
                        itemBuilder: (context, i) => cartePromo(promotions[i]),
                      ),
              ),
            ],
          ),
          floatingActionButton: estRestaurant
              ? FloatingActionButton(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  onPressed: () => ouvrirFormulaire(null),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Widget cartePromo(Promotion p) {
    bool estRestaurant = session.role == 'restaurant';
    bool valide = p.actif == 1 && !p.estExpiree();

    String etat = 'Active';
    if (p.estExpiree()) {
      etat = 'Expirée';
    } else if (p.actif == 0) {
      etat = 'Désactivée';
    }

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
                Container(
                  width: 80,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: valide ? orange : grisClair,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    p.type == '%'
                        ? '-${nombre(p.valeur)}%'
                        : '-${nombre(p.valeur)} TND',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.titre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Jusqu'au ${dateFr(p.dateFin)}",
                          style: const TextStyle(color: gris)),
                      if (estRestaurant)
                        Text(etat,
                            style: TextStyle(
                                color: valide ? vert : gris,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // le client clique sur le code pour l'utiliser
                // (on envoie le code a la page code promo avec pushNamed)
                InkWell(
                  onTap: estRestaurant
                      ? null
                      : () => Navigator.pushNamed(context, '/codePromo',
                          arguments: p.code),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: orangeClair,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(p.code,
                        style: const TextStyle(
                            color: orange, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Spacer(),
                if (estRestaurant)
                  TextButton(
                    // une promo expiree ne peut pas etre reactivee
                    onPressed: p.estExpiree() ? null : () => activerDesactiver(p),
                    child: Text(p.actif == 1 ? 'Désactiver' : 'Activer'),
                  ),
                if (estRestaurant)
                  IconButton(
                      onPressed: () => ouvrirFormulaire(p),
                      icon: const Icon(Icons.edit, color: gris)),
                if (estRestaurant)
                  IconButton(
                      onPressed: () => supprimer(p),
                      icon: const Icon(Icons.delete, color: rouge)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
