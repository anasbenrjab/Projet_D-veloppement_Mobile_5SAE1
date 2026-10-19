import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_utils.dart';
import '../../providers/profile_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class RestaurantProfileScreen extends ConsumerStatefulWidget {
  const RestaurantProfileScreen({super.key});

  @override
  ConsumerState<RestaurantProfileScreen> createState() =>
      _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState
    extends ConsumerState<RestaurantProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(profileProvider.notifier).loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);

    if (state.isLoading && state.data == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final profile = state.data ?? {};
    final name = profile['name'] ?? 'Mon Restaurant';
    final address = profile['address'] ?? '';
    final cuisineType = profile['cuisine_type'] ?? '';
    final description = profile['description'] ?? '';
    final photos = parseStringList(profile['photos']);
    final hours = parseJsonMap(profile['opening_hours']);
    final hoursIsEmpty = hours.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon restaurant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.of(context)
                  .pushNamed('/edit-restaurant-profile');
              ref.read(profileProvider.notifier).loadProfile();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header image
            Container(
              height: 200,
              color: AppColors.grey100,
              child: photos.isNotEmpty
                  ? Image.network(photos.first,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + cuisine
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (cuisineType.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(cuisineType,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (address.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.grey500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(address,
                              style: const TextStyle(
                                  color: AppColors.grey500,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 14, height: 1.5)),
                  ],
                  // Opening hours
                  if (!hoursIsEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Horaires d\'ouverture',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    ...hours.entries.map((e) => _HourRow(
                        day: e.key,
                        open: (e.value as Map)['open'] ?? '',
                        close: (e.value as Map)['close'] ?? '')),
                  ],
                  // Photos grid
                  if (photos.length > 1) ...[
                    const SizedBox(height: 20),
                    const Text('Photos',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8),
                      itemCount: photos.length,
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(photos[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: AppColors.grey100)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Logout
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Se déconnecter'),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.of(context)
                            .pushReplacementNamed('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.grey100,
        child: const Center(
            child: Icon(Icons.store, size: 72, color: AppColors.grey300)),
      );
}

class _HourRow extends StatelessWidget {
  const _HourRow(
      {required this.day, required this.open, required this.close});
  final String day, open, close;

  static const _days = {
    'mon': 'Lundi', 'tue': 'Mardi', 'wed': 'Mercredi',
    'thu': 'Jeudi', 'fri': 'Vendredi', 'sat': 'Samedi', 'sun': 'Dimanche'
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(_days[day] ?? day,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Text('$open – $close',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.grey500)),
        ],
      ),
    );
  }
}
