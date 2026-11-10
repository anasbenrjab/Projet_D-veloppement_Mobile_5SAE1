import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../recommendations/presentation/widgets/recommendation_carousel.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/widgets/restaurant_card.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../commande/presentation/screens/module2_shells.dart';

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
    if (index == 1) {
      Navigator.of(context).pushNamed(Routes.restaurants);
      return;
    }
    if (index == 2) {
      Navigator.of(context).pushNamed(Routes.favorites);
      return;
    }
    if (index == 3) {
      Navigator.of(context).pushNamed(Routes.myOrders);
      return;
    }
    if (index == 4) {
      Navigator.of(context).pushNamed(Routes.profile);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final clientProfile = profileState.data is ClientData
        ? (profileState.data! as ClientData).profile
        : null;
    final name = clientProfile?.fullName ?? 'vous';
    final fullName = clientProfile?.fullName?.trim() ?? '';
    final avatarName = fullName.isNotEmpty
        ? fullName
        : ref.watch(authProvider).user?.email ?? '';

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
                              Navigator.of(context).pushNamed(Routes.profile),
                          child: UserAvatar(
                            photoPath: clientProfile?.photoPath,
                            name: avatarName,
                          ),
                        ),
                      ],
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
            // ── Recommendations: restaurants, then dishes ──────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: RecommendationCarousel(),
              ),
            ),
            const SliverToBoxAdapter(child: DishRecommendationsSection()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: const Text('Vos restaurants favoris',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            // ── Favorite restaurants ───────────────────────────────────────
            const _FavoriteRestaurantsList(),
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

// ── _FavoriteRestaurantsList ─────────────────────────────────────────────────
/// The current client's favorite restaurants, with an empty state that points
/// to the favorites screen.
class _FavoriteRestaurantsList extends ConsumerWidget {
  const _FavoriteRestaurantsList();

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

    if (state.restaurants.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aucun restaurant favori pour le moment. Touchez le cœur '
                'sur un restaurant pour le retrouver ici.',
                style: TextStyle(color: AppColors.grey500, fontSize: 14),
              ),
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.favorites),
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Voir mes favoris'),
              ),
            ],
          ),
        ),
      );
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
                onTap: () => openRestaurantMenu(context, r.id, r.name),
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
