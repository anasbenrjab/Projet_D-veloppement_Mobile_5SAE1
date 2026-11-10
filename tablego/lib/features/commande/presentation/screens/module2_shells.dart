/// TableGo — Module 2 : Menu + Commande  (Roudaina Saoudi)
///
/// CRUD   : plats (restaurant), panier + commandes (client),
///          statut des commandes (restaurant).
/// IA     : assistant plats (description, catégorie, allergènes) + combos.
/// API    : TheMealDB (photos de plats + recettes similaires).
/// SQLite : sqflite sur mobile/desktop, store persistant sur le web.
///
/// Run: flutter run -d chrome
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app/navigation.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/commande/presentation/screens/cart_screen.dart';
import 'features/commande/presentation/screens/manage_orders_screen.dart';
import 'features/commande/presentation/screens/order_history_screen.dart';
import 'features/commande/data/models/order_model.dart';
import 'features/commande/providers/cart_provider.dart';
import 'features/commande/providers/order_provider.dart';
import 'features/menu/presentation/screens/add_edit_dish_screen.dart';
import 'features/menu/presentation/screens/dish_ai_assistant_screen.dart';
import 'features/menu/presentation/screens/manage_dishes_screen.dart';
import 'features/menu/presentation/screens/menu_screen.dart';
import 'features/menu/providers/dish_provider.dart';
import 'shared/widgets/tablego_bottom_nav.dart';
import 'shared/widgets/tablego_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.init();
  runApp(const ProviderScope(child: Module2App()));
}

class Module2App extends StatelessWidget {
  const Module2App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TableGo — Menu & Commande',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (_) => const WelcomeScreen(),
        '/client': (_) => const ClientShell(),
        '/restaurant': (_) => const RestaurantShell(),
        '/menu': (_) => const MenuScreen(),
        '/cart': (_) => const CartScreen(),
        '/orders': (_) => const OrderHistoryScreen(),
      },
    );
  }
}

// ── Welcome: choose a role ───────────────────────────────────────────────────

const _kHeroImage =
    'https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=1200&q=75&auto=format&fit=crop';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(_kHeroImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.textDark)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.25, 0.55, 1],
                colors: [
                  Color(0x99000000),
                  Color(0x11000000),
                  Color(0x55000000),
                  Color(0xF21E140E),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TableGoLogo(size: 36, textColor: Colors.white),
                  const Spacer(),
                  Text('Vos meilleures tables, à portée de main.',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 32,
                          height: 1.12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                      'Module Menu & Commande — choisissez votre espace pour commencer.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                          height: 1.4)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/client'),
                      icon: const Icon(Icons.arrow_forward, size: 20),
                      label: const Text('Commander (client)'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/restaurant'),
                      icon: const Icon(Icons.storefront_outlined,
                          color: Colors.white),
                      label: const Text('Espace restaurant',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Client shell ─────────────────────────────────────────────────────────────

/// One Scaffold, one bottom bar: Accueil · Menu · Panier · Commandes.
class ClientShell extends ConsumerStatefulWidget {
  const ClientShell({super.key});

  @override
  ConsumerState<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends ConsumerState<ClientShell> {
  @override
  void initState() {
    super.initState();
    // Dishes may have been edited in the restaurant space.
    Future.microtask(() {
      ref.read(clientTabProvider.notifier).state = ClientTab.home;
      ref.read(menuProvider.notifier).loadMenu();
      ref.read(cartProvider.notifier).loadCart();
    });
  }

  void _go(int tab) {
    if (tab == ClientTab.orders) ref.read(orderProvider.notifier).loadOrders();
    ref.read(clientTabProvider.notifier).state = tab;
  }

  void _switchToRestaurant() =>
      Navigator.of(context).pushReplacementNamed('/restaurant');

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(clientTabProvider);
    final cartCount = ref.watch(cartProvider).totalItems;

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: [
          MenuHomeTab(
            onOpenMenu: () => _go(ClientTab.menu),
            onSwitchRole: _switchToRestaurant,
          ),
          const MenuExplorerTab(),
          CartScreen(
              standalone: false, onBrowseMenu: () => _go(ClientTab.menu)),
          const _TabPage(
            title: 'Commandes',
            subtitle: 'Votre historique et le suivi en direct',
            child: OrderHistoryScreen(standalone: false),
          ),
        ],
      ),
      bottomNavigationBar: TableGoBottomNav(
        currentIndex: tab,
        onTap: _go,
        items: [
          const TableGoNavItem(Icons.home_outlined, 'Accueil'),
          const TableGoNavItem(Icons.restaurant_menu_outlined, 'Menu',
              activeIcon: Icons.restaurant_menu),
          TableGoNavItem(Icons.shopping_bag_outlined, 'Panier',
              activeIcon: Icons.shopping_bag, badge: cartCount),
          const TableGoNavItem(Icons.assignment_outlined, 'Commandes',
              activeIcon: Icons.assignment),
        ],
      ),
    );
  }
}

// ── Restaurant shell ─────────────────────────────────────────────────────────

/// One Scaffold, one bottom bar: Mes plats · Assistant IA · Commandes · Vue client.
class RestaurantShell extends ConsumerStatefulWidget {
  const RestaurantShell({super.key});

  @override
  ConsumerState<RestaurantShell> createState() => _RestaurantShellState();
}

class _RestaurantShellState extends ConsumerState<RestaurantShell> {
  static const _clientView = 3;

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
    if (i == _clientView) {
      Navigator.of(context).pushReplacementNamed('/client');
      return;
    }
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
              label: const Text('Ajouter un plat',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
      bottomNavigationBar: TableGoBottomNav(
        currentIndex: tab,
        onTap: _onTap,
        items: [
          const TableGoNavItem(Icons.restaurant_menu_outlined, 'Mes plats',
              activeIcon: Icons.restaurant_menu),
          const TableGoNavItem(Icons.auto_awesome_outlined, 'Assistant IA',
              activeIcon: Icons.auto_awesome),
          TableGoNavItem(Icons.receipt_long_outlined, 'Commandes',
              activeIcon: Icons.receipt_long, badge: pending),
          const TableGoNavItem(Icons.person_outline, 'Vue client'),
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
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(subtitle,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          const SizedBox(height: 4),
          Expanded(child: child),
        ],
      ),
    );
  }
}
