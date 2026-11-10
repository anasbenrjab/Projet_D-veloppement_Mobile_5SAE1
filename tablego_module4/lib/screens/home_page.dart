import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../db/database_helper.dart';
import '../models/ingredient.dart';
import '../session.dart' as session;
import 'ingredients_page.dart';
import 'pertes_page.dart';
import 'offres_page.dart';
import 'ia_page.dart';
import 'mes_reservations_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  DatabaseHelper dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    alerteStock();
  }

  // alerte a l'ouverture : ingredients perimes ou qui expirent bientot
  void alerteStock() async {
    if (session.role != 'restaurant') return;
    List<Ingredient> stock = await dbHelper.getIngredients(session.restaurantId);
    List<Ingredient> urgents =
        stock.where((i) => i.estPerime() || i.expireBientot()).toList();
    if (urgents.isEmpty || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: orange, size: 40),
        title: const Text('Alerte stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${urgents.length} ingrédient(s) à utiliser vite :'),
            const SizedBox(height: 8),
            for (Ingredient i in urgents)
              Text(
                i.estPerime()
                    ? '• ${i.nom} : périmé'
                    : '• ${i.nom} : ${i.joursAvantPeremption()} jour(s)',
                style: TextStyle(color: i.estPerime() ? rouge : brun),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void choisirRole(String r) {
    setState(() {
      session.changerRole(r);
      index = 0; // les onglets ne sont pas les memes
    });
    Navigator.pop(context); // fermer le drawer
  }

  @override
  Widget build(BuildContext context) {
    bool estRestaurant = session.role == 'restaurant';

    List<Widget> pages;
    List<String> titres;
    List<BottomNavigationBarItem> items;

    if (estRestaurant) {
      pages = [
        const IngredientsPage(),
        const PertesPage(),
        const OffresPage(key: ValueKey('offres_restaurant')),
        const IaPage(),
      ];
      titres = ['Stock', 'Gaspillage', 'Offres anti-gaspi', 'Assistant IA'];
      items = const [
        BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
        BottomNavigationBarItem(
            icon: Icon(Icons.delete_outline), label: 'Gaspillage'),
        BottomNavigationBarItem(
            icon: Icon(Icons.local_offer_outlined), label: 'Offres'),
        BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'IA'),
      ];
    } else {
      pages = [
        const OffresPage(key: ValueKey('offres_client')),
        const MesReservationsPage(),
      ];
      titres = ['Offres anti-gaspi', 'Mes réservations'];
      items = const [
        BottomNavigationBarItem(
            icon: Icon(Icons.local_offer_outlined), label: 'Offres'),
        BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined), label: 'Réservations'),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titres[index]),
      ),
      // pour tester les 2 roles (normalement c'est le login du module 1 qui decide)
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: orange),
              child: Text('Connecté : ${session.userNom}',
                  style: const TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Vue restaurant'),
              selected: session.role == 'restaurant',
              onTap: () => choisirRole('restaurant'),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Vue client'),
              selected: session.role == 'client',
              onTap: () => choisirRole('client'),
            ),
          ],
        ),
      ),
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: orange,
        unselectedItemColor: gris,
        backgroundColor: Colors.white,
        onTap: (i) {
          setState(() {
            index = i;
          });
        },
        items: items,
      ),
    );
  }
}
