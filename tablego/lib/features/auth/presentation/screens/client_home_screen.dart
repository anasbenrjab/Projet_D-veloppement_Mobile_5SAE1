import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../recommendations/presentation/widgets/recommendation_carousel.dart';
import '../../../../features/auth/providers/auth_provider.dart';
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
    Future.microtask(() {
      final userId = ref.read(authProvider).user?.id;
      if (userId != null) {
        ref.read(profileProvider.notifier).loadClientProfile(userId);
      }
    });
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
    final profileState = ref.watch(profileProvider);
    final String name;
    if (profileState.data is ClientData) {
      name = (profileState.data! as ClientData).profile.fullName ?? 'vous';
    } else {
      name = 'vous';
    }

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
                    // ── Greeting ───────────────────────────────────────────
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
                                AppColors.primary.withValues(alpha: 0.15),
                            child: const Icon(Icons.person,
                                color: AppColors.primary, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ── Search bar (placeholder for Module 2) ──────────────
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
                                    color: AppColors.grey500,
                                    fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // ── Recommendations header ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Recommandé pour vous',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 16, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('IA',
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
            // ── Recommendations carousel ───────────────────────────────────
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
            // ── Nearby (uses favorites as placeholder — TODO Module 2) ─────
            const _NearbyList(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
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
              selectedIcon:
                  Icon(Icons.favorite, color: AppColors.primary),
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

// ── _NearbyList ───────────────────────────────────────────────────────────────
// TODO(module-2): replace with actual nearby/search API.
// Currently uses the current user's favorite restaurants as placeholder data.
class _NearbyList extends ConsumerWidget {
  const _NearbyList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).user?.id;
    if (userId == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final state  = ref.watch(favoriteRestaurantsProvider(userId));
    final favIds = state.restaurants.map((r) => r.id).toSet();

    if (state.isLoading && state.restaurants.isEmpty) {
      return const SliverToBoxAdapter(
          child: Center(child: CircularProgressIndicator()));
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            final r = state.restaurants[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RestaurantCard(
                name:        r.name,
                cuisineType: r.cuisineType,
                address:     r.address,
                photoPath:   r.firstPhotoPath,
                isFavorite:  favIds.contains(r.id),
                onFavoriteTap: () => ref
                    .read(favoriteRestaurantsProvider(userId).notifier)
                    .toggle(r.id),
              ),
            );
          },
          childCount: state.restaurants.length,
        ),
      ),
    );
  }
}
