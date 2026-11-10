/// TableGo — Module 5 : Avis + Promotions  (Mouhib Lafi)
///
/// CRUD   : avis (client), reponse aux avis et promotions (restaurant).
/// IA     : sentiment des avis + detection spam / mots offensants.
/// API    : MyMemory (traduction d'un avis en anglais).
/// SQLite : la base commune de TableGo (tablego.db).
///
/// Integration : le Drawer « Vue client / Vue restaurant » est remplace par
/// le login de TableGo. Ces widgets sont les entrees du module dans la
/// navigation ; ils lisent l'utilisateur connecte (`authProvider`) et
/// remplissent `session.dart` avant d'afficher [HomePage] :
///
/// * [AvisClientTab]     — client, dans la page d'un restaurant ;
/// * [AvisRestaurantTab] — compte restaurant : ses avis et ses promotions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/current_restaurant.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../session.dart' as session;
import 'home_page.dart';

/// Cote client : avis et promotions du restaurant [restaurantId].
class AvisClientTab extends ConsumerWidget {
  const AvisClientTab(
      {super.key, required this.restaurantId, required this.restaurantNom});

  final int restaurantId; // restaurant_profiles.id
  final String restaurantNom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider.select((s) => s.user));
    if (user == null) return const SizedBox.shrink();
    return ConnexionModule5(
      key: ValueKey('client-${user.id}-$restaurantId'),
      role: 'client',
      userId: user.id,
      email: user.email,
      restaurantId: restaurantId,
      restaurantNom: restaurantNom,
    );
  }
}

/// Cote restaurant : les avis et les promotions du restaurant connecte.
class AvisRestaurantTab extends ConsumerWidget {
  const AvisRestaurantTab({super.key});

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
            return ConnexionModule5(
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
class ConnexionModule5 extends StatefulWidget {
  const ConnexionModule5({
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
  State<ConnexionModule5> createState() => _ConnexionModule5State();
}

class _ConnexionModule5State extends State<ConnexionModule5> {
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
