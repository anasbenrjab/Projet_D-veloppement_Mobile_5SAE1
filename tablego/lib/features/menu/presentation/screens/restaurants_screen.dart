import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_utils.dart';
import '../../../../shared/widgets/restaurant_card.dart';
import '../../../commande/presentation/screens/module2_shells.dart';

/// One row of the client's restaurant list.
class RestaurantListItem {
  const RestaurantListItem({
    required this.id,
    required this.name,
    required this.address,
    required this.cuisineType,
    this.photoPath,
  });

  /// `restaurant_profiles.id`.
  final int id;
  final String name;
  final String address;
  final String cuisineType;
  final String? photoPath;
}

/// Every restaurant with an active account, by name.
final restaurantListProvider =
    FutureProvider.autoDispose<List<RestaurantListItem>>((ref) async {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
    SELECT rp.id, rp.name, rp.address, rp.cuisine_type, rp.photo_paths
      FROM restaurant_profiles rp
      JOIN users u ON u.id = rp.user_id AND u.is_active = 1
     ORDER BY rp.name COLLATE NOCASE
  ''');
      return [
        for (final r in rows)
          RestaurantListItem(
            id: r['id']! as int,
            name: r['name']! as String,
            address: (r['address'] as String?) ?? '',
            cuisineType: (r['cuisine_type'] as String?) ?? '',
            photoPath: parseStringList(r['photo_paths']).firstOrNull,
          ),
      ];
    });

/// "Explorer" (client): pick a restaurant to see its menu and order.
class RestaurantsScreen extends ConsumerWidget {
  const RestaurantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(restaurantListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurants')),
      body: restaurants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossible de charger les restaurants.\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Aucun restaurant pour le moment.'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(restaurantListProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return RestaurantCard(
                      name: r.name,
                      cuisineType: r.cuisineType,
                      address: r.address,
                      photoPath: r.photoPath,
                      onTap: () => openRestaurantMenu(context, r.id, r.name),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
