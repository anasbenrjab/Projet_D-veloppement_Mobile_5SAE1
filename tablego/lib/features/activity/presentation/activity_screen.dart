import 'package:flutter/material.dart';

import '../../commande/presentation/screens/order_history_screen.dart';
import '../../events/screens/module3_entrees.dart';

/// Client « Activité »: the client's orders (Module 2) and table
/// reservations (Module 3), every restaurant.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activité'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Commandes', icon: Icon(Icons.receipt_long_outlined)),
              Tab(text: 'Réservations', icon: Icon(Icons.event_seat_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            OrderHistoryScreen(standalone: false),
            MesReservationsScreen(),
          ],
        ),
      ),
    );
  }
}
