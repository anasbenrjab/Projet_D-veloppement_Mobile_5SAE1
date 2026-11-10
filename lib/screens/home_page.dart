import 'package:flutter/material.dart';
import '../couleurs.dart';
import '../session.dart' as session;
import 'avis_page.dart';
import 'promotions_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  void choisirRole(String r) {
    setState(() {
      session.changerRole(r);
    });
    Navigator.pop(context); // fermer le drawer
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      const AvisPage(),
      const PromotionsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(index == 0 ? 'Avis' : 'Promotions'),
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
              leading: const Icon(Icons.person),
              title: const Text('Vue client'),
              selected: session.role == 'client',
              onTap: () => choisirRole('client'),
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Vue restaurant'),
              selected: session.role == 'restaurant',
              onTap: () => choisirRole('restaurant'),
            ),
          ],
        ),
      ),
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        selectedItemColor: orange,
        unselectedItemColor: gris,
        backgroundColor: Colors.white,
        onTap: (i) {
          setState(() {
            index = i;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.star_border), label: 'Avis'),
          BottomNavigationBarItem(
              icon: Icon(Icons.local_offer_outlined), label: 'Promotions'),
        ],
      ),
    );
  }
}
