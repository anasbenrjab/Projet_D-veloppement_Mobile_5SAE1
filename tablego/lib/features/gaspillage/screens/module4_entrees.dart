/// TableGo — Module 4 : Gaspillage alimentaire  (Fatma Ghil)
///
/// CRUD   : ingredients (stock + alertes), journal de gaspillage
///          (+ statistiques), offres anti-gaspi (restaurant) et
///          reservation des offres (client).
/// IA     : quantite a preparer chaque jour, idees de plats avec les
///          ingredients proches de la peremption, prix de reduction juste.
/// API    : TheMealDB (d'autres recettes avec un ingredient).
/// SQLite : la base commune de TableGo (tablego.db).
///
/// Integration : le Drawer « Vue client / Vue restaurant » est remplace par
/// le login de TableGo. Ces widgets sont les entrees du module dans la
/// navigation ; ils lisent l'utilisateur connecte (`authProvider`) et
/// remplissent `session.dart` avant d'afficher [HomePage] :
///
/// * [AntiGaspiClientTab]     — client, dans la page d'un restaurant ;
/// * [AntiGaspiRestaurantTab] — compte restaurant : stock, pertes, offres, IA.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/current_restaurant.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../session.dart' as session;
import 'home_page.dart';

/// Cote client : offres anti-gaspi du restaurant [restaurantId].
class AntiGaspiClientTab extends ConsumerWidget {
  const AntiGaspiClientTab(
      {super.key, required this.restaurantId, required this.restaurantNom});

  final int restaurantId; // restaurant_profiles.id
  final String restaurantNom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    if (user == null) return const SizedBox.shrink();
    return ConnexionModule4(
      key: ValueKey('client-${user.id}-$restaurantId'),
      role: 'client',
      userId: user.id,
      email: user.email,
      restaurantId: restaurantId,
      restaurantNom: restaurantNom,
    );
  }
}

/// Cote restaurant : stock, journal, offres et IA du restaurant connecte.
class AntiGaspiRestaurantTab extends ConsumerWidget {
  const AntiGaspiRestaurantTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    return ref.watch(currentRestaurantIdProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (restaurantId) {
            if (user == null || restaurantId == null) {
              return const Center(
                  child: Text("Ce compte n'a pas de profil restaurant."));
            }
            return ConnexionModule4(
              key: ValueKey('restaurant-${user.id}-$restaurantId'),
              role: 'restaurant',
              userId: user.id,
              email: user.email,
              restaurantId: restaurantId,
            );
          },
        );
  }
}

/// Cherche les noms dans la base, remplit la session puis affiche [HomePage].
class ConnexionModule4 extends StatefulWidget {
  const ConnexionModule4({
    super.key,
    required this.role,
    required this.userId,
    required this.email,
    required this.restaurantId,
    this.restaurantNom,
  });

  final String role;
  final int userId;
  final String email;
  final int restaurantId;
  final String? restaurantNom;

  @override
  State<ConnexionModule4> createState() => _ConnexionModule4State();
}

class _ConnexionModule4State extends State<ConnexionModule4> {
  late Future<bool> futureConnexion;

  @override
  void initState() {
    super.initState();
    futureConnexion = connecter();
  }

  Future<bool> connecter() async {
    final db = await DatabaseHelper.instance.database;

    String nomResto = widget.restaurantNom ??
        await restaurantName(db, widget.restaurantId) ??
        'Restaurant';

    String nomUser;
    if (widget.role == 'restaurant') {
      nomUser = nomResto;
    } else {
      // nom du profil client, sinon l'email
      List<Map<String, Object?>> res = await db.query('client_profiles',
          columns: ['full_name'],
          where: 'user_id = ?',
          whereArgs: [widget.userId]);
      String? nom = res.isEmpty ? null : res.first['full_name'] as String?;
      nomUser = (nom == null || nom.trim().isEmpty) ? widget.email : nom;
    }

    session.connecter(
        widget.role, widget.userId, nomUser, widget.restaurantId, nomResto);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: futureConnexion,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return const HomePage();
      },
    );
  }
}
