import 'package:flutter/material.dart';
import '../couleurs.dart';
import 'avis_page.dart';
import 'promotions_page.dart';

// onglet "Avis" de TableGo : deux boutons en haut pour choisir
// Avis ou Promotions (la barre du bas est celle de l'application)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  // bouton pour choisir la page (orange = choisi)
  Widget boutonPage(int i, IconData icone, String texte) {
    bool choisi = index == i;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: choisi ? orange : Colors.white,
            foregroundColor: choisi ? Colors.white : brun,
          ),
          onPressed: () {
            setState(() {
              index = i;
            });
          },
          icon: Icon(icone),
          label: Text(texte),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      const AvisPage(),
      const PromotionsPage(),
    ];

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                boutonPage(0, Icons.star_border, 'Avis'),
                boutonPage(1, Icons.local_offer_outlined, 'Promotions'),
              ],
            ),
          ),
          Expanded(child: pages[index]),
        ],
      ),
    );
  }
}
