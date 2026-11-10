import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../session.dart' as session;
import 'ingredients_page.dart';
import 'pertes_page.dart';
import 'offres_page.dart';
import 'ia_page.dart';
import 'mes_reservations_page.dart';

// onglet "Anti-gaspi" de TableGo : des boutons en haut pour choisir la page
// (la barre du bas est celle de l'application)
// restaurant : Stock, Pertes, Offres, IA
// client     : Offres, Mes réservations
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: choisi ? orange : Colors.white,
          foregroundColor: choisi ? Colors.white : brun,
          // le theme de TableGo met des boutons pleine largeur :
          // ici les boutons sont dans une ligne qui defile
          minimumSize: const Size(0, 44),
        ),
        onPressed: () {
          setState(() {
            index = i;
          });
        },
        icon: Icon(icone),
        label: Text(texte),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool estRestaurant = session.role == 'restaurant';

    List<Widget> pages;
    List<Widget> boutons;
    if (estRestaurant) {
      pages = [
        const IngredientsPage(),
        const PertesPage(),
        const OffresPage(),
        const IaPage(),
      ];
      boutons = [
        boutonPage(0, Icons.inventory_2_outlined, 'Stock'),
        boutonPage(1, Icons.delete_outline, 'Pertes'),
        boutonPage(2, Icons.local_offer_outlined, 'Offres'),
        boutonPage(3, Icons.auto_awesome, 'IA'),
      ];
    } else {
      pages = [
        const OffresPage(),
        const MesReservationsPage(),
      ];
      boutons = [
        boutonPage(0, Icons.local_offer_outlined, 'Offres'),
        boutonPage(1, Icons.shopping_bag_outlined, 'Mes réservations'),
      ];
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // 4 boutons ne tiennent pas toujours sur un petit telephone :
          // on peut les faire defiler
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(children: boutons),
          ),
          Expanded(child: pages[index]),
        ],
      ),
    );
  }
}
