import 'package:flutter/material.dart';

import 'ecran_choix_client.dart';
import 'restaurant/ecran_accueil_restaurant.dart';

/// Premier écran de l'application : on choisit simplement son rôle.
/// Pas d'authentification complexe — c'est une démo pédagogique.
class EcranChoixRole extends StatelessWidget {
  const EcranChoixRole({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Dégradé de fond pour donner un ton "restaurant" à l'accueil.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepOrange.shade400,
              Colors.deepOrange.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant_menu,
                    size: 72, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'Resto Events',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Module 3 — Événements & Réservations',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 48),
                _CarteRole(
                  icone: Icons.storefront,
                  titre: 'Je suis un restaurant',
                  sousTitre: 'Gérer les demandes, l\'affluence et les événements',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EcranAccueilRestaurant(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _CarteRole(
                  icone: Icons.person,
                  titre: 'Je suis un client',
                  sousTitre: 'Réserver une table en quelques secondes',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EcranChoixClient(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte cliquable représentant un rôle.
class _CarteRole extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback onTap;

  const _CarteRole({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Card(
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icone, size: 40, color: Colors.deepOrange),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sousTitre,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
