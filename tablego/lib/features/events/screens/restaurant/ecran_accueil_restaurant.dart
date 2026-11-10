import 'package:flutter/material.dart';

import '../../database/evenements_repository.dart';
import 'ecran_affluence.dart';
import 'ecran_demandes.dart';
import 'ecran_evenements.dart';

/// Écran d'accueil du restaurant, organisé en trois onglets :
///   - Demandes : accepter / refuser les réservations ;
///   - Affluence IA : créneaux chargés prédits par l'IA locale ;
///   - Événements : CRUD complet des événements du restaurant.
class EcranAccueilRestaurant extends StatefulWidget {
  const EcranAccueilRestaurant({super.key, required this.restaurantId});

  /// `restaurant_profiles.id` du restaurant connecté (intégration TableGo :
  /// le Module 3 utilisait son unique restaurant, id 1).
  final int restaurantId;

  @override
  State<EcranAccueilRestaurant> createState() => _EcranAccueilRestaurantState();
}

class _EcranAccueilRestaurantState extends State<EcranAccueilRestaurant> {
  String _nomRestaurant = 'Restaurant';
  int _capacite = 40;

  @override
  void initState() {
    super.initState();
    _chargerInfos();
  }

  Future<void> _chargerInfos() async {
    try {
      final restaurant = await EvenementsRepository.instance
          .restaurant(widget.restaurantId);
      if (!mounted) return;
      setState(() {
        _nomRestaurant = restaurant.nom;
        _capacite = restaurant.capaciteMax;
      });
    } catch (_) {
      // L'écran reste utilisable avec les valeurs par défaut.
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_nomRestaurant),
              Text(
                'Capacité : $_capacite personnes par créneau',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Demandes', icon: Icon(Icons.inbox)),
              Tab(text: 'Affluence IA', icon: Icon(Icons.insights)),
              Tab(text: 'Événements', icon: Icon(Icons.celebration)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            EcranDemandes(restaurantId: widget.restaurantId),
            EcranAffluence(restaurantId: widget.restaurantId),
            EcranEvenements(restaurantId: widget.restaurantId),
          ],
        ),
      ),
    );
  }
}
