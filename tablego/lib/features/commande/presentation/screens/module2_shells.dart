/// TableGo — Module 2 : Menu + Commande  (Roudaina Saoudi)
///
/// CRUD   : plats (restaurant), panier + commandes (client),
///          statut des commandes (restaurant).
/// IA     : assistant plats (description, catégorie, allergènes) + combos.
/// API    : TheMealDB (photos de plats + recettes similaires).
/// SQLite : the shared TableGo database (`DatabaseHelper`, sqflite on
///          mobile, sqlite3-wasm on web).
///
/// Integration: the role-choice welcome screen is replaced by TableGo's
/// login.  [ClientShell] is opened for one restaurant (from the client's
/// restaurant list), [RestaurantShell] is the restaurant account's home.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../menu/presentation/screens/add_edit_dish_screen.dart';
import '../../../menu/presentation/screens/dish_ai_assistant_screen.dart';
import '../../../menu/presentation/screens/manage_dishes_screen.dart';
import '../../../menu/presentation/screens/menu_screen.dart';
import '../../../menu/providers/dish_provider.dart';
import '../../../events/screens/module3_entrees.dart';
import '../../../avis_promotions/screens/module5_entrees.dart';
import '../../../gaspillage/screens/module4_entrees.dart';
import '../../../profile/presentation/screens/restaurant_profile_screen.dart';
import '../../../../shared/widgets/tablego_bottom_nav.dart';
import '../../data/models/order_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../navigation.dart';
import 'cart_screen.dart';
import 'manage_orders_screen.dart';
import 'order_history_screen.dart';

/// Arguments of [Routes.restaurantMenu].
class RestaurantMenuArgs {
  const RestaurantMenuArgs({required this.restaurantId, required this.name});

  /// `restaurant_profiles.id`.
  final int restaurantId;
  final String name;
}

/// Opens [ClientShell] for a restaurant.
Future<void> openRestaurantMenu(
  BuildContext context,
  int restaurantId,
  String name,
) => Navigator.of(context).pushNamed(
  Routes.restaurantMenu,
  arguments: RestaurantMenuArgs(restaurantId: restaurantId, name: name),
);

// ── Client shell ─────────────────────────────────────────────────────────────

/// One Scaffold, one bottom bar: Accueil · Menu · Panier · Commandes, for the
/// restaurant in [args].  The menu and the cart are scoped to it through
/// [selectedRestaurantProvider].
class ClientShell extends ConsumerStatefulWidget {
  const ClientShell({super.key, required this.args});

  final RestaurantMenuArgs args;

  @override
  ConsumerState<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends ConsumerState<ClientShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(clientTabProvider.notifier).state = ClientTab.home;
      // menuProvider and cartProvider watch this and reload for it.
      ref.read(selectedRestaurantProvider.notifier).state =
          widget.args.restaurantId;
    });
  }

  void _go(int tab) {
    if (tab == ClientTab.orders) ref.read(orderProvider.notifier).loadOrders();
    ref.read(clientTabProvider.notifier).state = tab;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(clientTabProvider);
    final cartCount = ref.watch(cartProvider).totalItems;

    return Scaffold(
      body: Column(
        children: [
          // Integration: the way back to the main client shell (Profil,
          // logout…), shown above every tab of this restaurant view.
          _LeaveRestaurantBar(name: widget.args.name),
          // The bar above already consumed the status-bar inset.
          Expanded(
            child: MediaQuery.removePadding(
                context: context, removeTop: true, child: _tabs(tab)),
          ),
        ],
      ),
      bottomNavigationBar: _bottomNav(tab, cartCount),
    );
  }

  Widget _tabs(int tab) => IndexedStack(
        index: tab,
        children: [
          MenuHomeTab(
            restaurantName: widget.args.name,
            onOpenMenu: () => _go(ClientTab.menu),
          ),
          const MenuExplorerTab(),
          CartScreen(
            standalone: false,
            onBrowseMenu: () => _go(ClientTab.menu),
          ),
          const _TabPage(
            title: 'Commandes',
            subtitle: 'Votre historique et le suivi en direct',
            child: OrderHistoryScreen(standalone: false),
          ),
          // Module 3: events + table reservations at this restaurant.
          ReserverTableTab(restaurantId: widget.args.restaurantId),
          // Module 5: reviews + promotions of this restaurant.
          AvisClientTab(
            restaurantId: widget.args.restaurantId,
            restaurantNom: widget.args.name,
          ),
          // Module 4: anti-waste offers of this restaurant.
          AntiGaspiClientTab(
            restaurantId: widget.args.restaurantId,
            restaurantNom: widget.args.name,
          ),
        ],
      );

  Widget _bottomNav(int tab, int cartCount) => TableGoBottomNav(
        currentIndex: tab,
        onTap: _go,
        items: [
          const TableGoNavItem(Icons.home_outlined, 'Accueil'),
          const TableGoNavItem(
            Icons.restaurant_menu_outlined,
            'Menu',
            activeIcon: Icons.restaurant_menu,
          ),
          TableGoNavItem(
            Icons.shopping_bag_outlined,
            'Panier',
            activeIcon: Icons.shopping_bag,
            badge: cartCount,
          ),
          const TableGoNavItem(
            Icons.assignment_outlined,
            'Commandes',
            activeIcon: Icons.assignment,
          ),
          const TableGoNavItem(
            Icons.event_seat_outlined,
            'Réserver',
            activeIcon: Icons.event_seat,
          ),
          const TableGoNavItem(
            Icons.star_border,
            'Avis',
            activeIcon: Icons.star,
          ),
          const TableGoNavItem(
            Icons.eco_outlined,
            'Anti-gaspi',
            activeIcon: Icons.eco,
          ),
        ],
      );
}

/// Top bar of the restaurant view: back to the main client shell.
class _LeaveRestaurantBar extends StatelessWidget {
  const _LeaveRestaurantBar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              IconButton(
                key: const Key('leave_restaurant'),
                icon: const Icon(Icons.arrow_back),
                tooltip: "Retour à l'accueil",
                onPressed: () => leaveRestaurant(context),
              ),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Restaurant shell ─────────────────────────────────────────────────────────

/// Home of a restaurant account.  One Scaffold, one bottom bar:
/// Mes plats · Assistant IA · Commandes · Réservations (Module 3) ·
/// Mon restaurant (profile).
class RestaurantShell extends ConsumerStatefulWidget {
  const RestaurantShell({super.key});

  @override
  ConsumerState<RestaurantShell> createState() => _RestaurantShellState();
}

class _RestaurantShellState extends ConsumerState<RestaurantShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(restaurantTabProvider.notifier).state = RestaurantTab.dishes;
      ref.read(dishProvider.notifier).loadAll();
      ref.read(orderProvider.notifier).loadOrders();
    });
  }

  void _onTap(int i) {
    if (i == RestaurantTab.orders) {
      ref.read(orderProvider.notifier).loadOrders();
    }
    ref.read(restaurantTabProvider.notifier).state = i;
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(restaurantTabProvider);
    final pending = ref
        .watch(orderProvider)
        .orders
        .where((o) => o.status == OrderStatus.received)
        .length;

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          ManageDishesScreen(embedded: true),
          _TabPage(
            title: 'Assistant IA',
            subtitle: 'Description, catégorie et allergènes en un clic',
            scrollable: true,
            child: DishAiAssistantScreen(standalone: false),
          ),
          _TabPage(
            title: 'Commandes',
            subtitle: 'Mettez à jour le statut des commandes',
            child: ManageOrdersScreen(standalone: false),
          ),
          // Module 3: requests, AI affluence, events.
          ReservationsRestaurantTab(),
          // Module 5: reviews (replies, spam) + promotions.
          AvisRestaurantTab(),
          // Module 4: stock, waste log, anti-waste offers, AI.
          AntiGaspiRestaurantTab(),
          RestaurantProfileScreen(),
        ],
      ),
      floatingActionButton: tab == RestaurantTab.dishes
          ? FloatingActionButton.extended(
              heroTag: 'add_dish',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditDishScreen()),
              ),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Ajouter un plat',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      bottomNavigationBar: TableGoBottomNav(
        currentIndex: tab,
        onTap: _onTap,
        items: [
          const TableGoNavItem(
            Icons.restaurant_menu_outlined,
            'Mes plats',
            activeIcon: Icons.restaurant_menu,
          ),
          const TableGoNavItem(
            Icons.auto_awesome_outlined,
            'Assistant IA',
            activeIcon: Icons.auto_awesome,
          ),
          TableGoNavItem(
            Icons.receipt_long_outlined,
            'Commandes',
            activeIcon: Icons.receipt_long,
            badge: pending,
          ),
          const TableGoNavItem(
            Icons.event_note_outlined,
            'Réservations',
            activeIcon: Icons.event_note,
          ),
          const TableGoNavItem(
            Icons.star_border,
            'Avis',
            activeIcon: Icons.star,
          ),
          const TableGoNavItem(
            Icons.eco_outlined,
            'Anti-gaspi',
            activeIcon: Icons.eco,
          ),
          const TableGoNavItem(
            Icons.storefront_outlined,
            'Mon restaurant',
            activeIcon: Icons.storefront,
          ),
        ],
      ),
    );
  }
}

/// Page header (big Poppins title + subtitle) above an embedded screen.
class _TabPage extends StatelessWidget {
  const _TabPage({
    required this.title,
    required this.subtitle,
    required this.child,
    this.scrollable = false,
  });

  final String title, subtitle;
  final Widget child;

  /// The child is a plain list of widgets (not a scroll view).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: child),
        ],
      ),
    );
  }
}
