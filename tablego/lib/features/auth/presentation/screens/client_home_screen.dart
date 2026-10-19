import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_utils.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../recommendations/presentation/widgets/recommendation_carousel.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../../shared/widgets/restaurant_card.dart';

class ClientHomeScreen extends ConsumerStatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  ConsumerState<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends ConsumerState<ClientHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileProvider.notifier).loadProfile());
  }

  void _onNavTap(int index) {
    if (index == 2) {
      Navigator.of(context).pushNamed('/favorites');
      return;
    }
    if (index == 4) {
      Navigator.of(context).pushNamed('/profile');
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).data;
    final name = profile?['full_name'] ?? 'vous';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bonjour, $name 👋',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text('Que voulez-vous manger ?',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.grey500)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.of(context).pushNamed('/profile'),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                AppColors.primary.withOpacity(0.15),
                            child: const Icon(Icons.person,
                                color: AppColors.primary, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Search bar
                    GestureDetector(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Recherche — Module 2'))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.grey300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search,
                                color: AppColors.grey500, size: 20),
                            SizedBox(width: 10),
                            Text('Restaurants, plats...',
                                style: TextStyle(
                                    color: AppColors.grey500, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Recommendations section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recommandé pour vous',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            const Text('IA',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Recommendations carousel
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: RecommendationCarousel(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: const Text('À proximité',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            // Nearby = same data as recommendations for now
            _NearbyList(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore, color: AppColors.primary),
              label: 'Explorer'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite, color: AppColors.primary),
              label: 'Favoris'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon:
                  Icon(Icons.receipt_long, color: AppColors.primary),
              label: 'Activité'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Profil'),
        ],
      ),
    );
  }
}

class _NearbyList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favState = ref.watch(favoriteRestaurantsProvider);
    final favIds = favState.valueOrNull?.map((r) => r['id'] as int).toSet() ?? {};

    // Using favorites as nearby placeholder
    return favState.when(
      loading: () => const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (restaurants) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final r = restaurants[i];
              final id = r['id'] as int;
              final photos = parseStringList(r['photos']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RestaurantCard(
                  name: r['name'] ?? '',
                  cuisineType: r['cuisine_type'] ?? '',
                  address: r['address'] ?? '',
                  photoUrl: photos.isNotEmpty ? photos.first : null,
                  isFavorite: favIds.contains(id),
                  onFavoriteTap: () => ref
                      .read(favoriteRestaurantsProvider.notifier)
                      .toggle(id),
                ),
              );
            },
            childCount: restaurants.length,
          ),
        ),
      ),
    );
  }
}
