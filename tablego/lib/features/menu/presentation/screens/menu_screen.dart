import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/dish_image.dart';
import '../../data/models/dish_model.dart';
import '../../providers/dish_provider.dart';
import '../../../commande/providers/cart_provider.dart';
import '../../../commande/presentation/screens/cart_screen.dart';
import 'dish_detail_screen.dart';

String formatPrice(double p) => '${p.toStringAsFixed(3).replaceAll('.', ',')} DT';

IconData categoryIcon(String? c) => switch (c) {
      null => Icons.restaurant_menu,
      'Entrée' => Icons.soup_kitchen_outlined,
      'Plat principal' => Icons.restaurant,
      'Dessert' => Icons.cake_outlined,
      'Boisson' => Icons.local_cafe_outlined,
      'Snack' => Icons.fastfood_outlined,
      'Menu enfant' => Icons.child_care,
      _ => Icons.star_outline,
    };

void openDish(BuildContext context, DishModel dish) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => DishDetailScreen(dishId: dish.id!)));

// ── Accueil (client) ─────────────────────────────────────────────────────────

/// Client home: restaurant header, search, "Plat du jour" hero card,
/// category chips and popular dishes — styled after the TableGo mockup.
class MenuHomeTab extends ConsumerStatefulWidget {
  const MenuHomeTab({super.key, this.onOpenMenu, this.onSwitchRole});
  final VoidCallback? onOpenMenu;
  final VoidCallback? onSwitchRole;

  @override
  ConsumerState<MenuHomeTab> createState() => _MenuHomeTabState();
}

class _MenuHomeTabState extends ConsumerState<MenuHomeTab> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(menuProvider);
    final dishes = state.dishes;
    final featured = dishes
            .where((d) => d.category == 'Plat principal' && d.imagePath != null)
            .firstOrNull ??
        dishes.firstOrNull;
    final categories = DishModel.categories
        .where((c) => dishes.any((d) => d.category == c))
        .toList();
    final shown = _category == null
        ? dishes
        : dishes.where((d) => d.category == _category).toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(menuProvider.notifier).loadMenu(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bonjour 👋',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('Dar Slah · La Marsa',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark)),
                          ),
                          const Icon(Icons.keyboard_arrow_down,
                              color: AppColors.textDark, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Espace restaurant',
                  child: InkWell(
                    onTap: widget.onSwitchRole,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppColors.peach, shape: BoxShape.circle),
                      child: const Icon(Icons.storefront_outlined,
                          color: AppColors.primary, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Search (opens the Menu tab)
            GestureDetector(
              onTap: widget.onOpenMenu,
              child: Container(
                height: 52,
                padding: const EdgeInsets.only(left: 14, right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textDark.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search,
                        color: AppColors.textDark, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Rechercher un plat...',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 14)),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.peach,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune,
                          color: AppColors.primary, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (state.isLoading)
              const SizedBox(
                  height: 200,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)))
            else if (featured != null)
              _FeaturedDishCard(dish: featured),
            const SizedBox(height: 16),
            // Category chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  CategoryChip(
                    label: 'Tout',
                    icon: null,
                    active: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in categories) ...[
                    const SizedBox(width: 8),
                    CategoryChip(
                      label: c,
                      icon: categoryIcon(c),
                      active: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text('Populaires',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                ),
                GestureDetector(
                  onTap: widget.onOpenMenu,
                  child: const Text('Voir tout',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty && !state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: Text('Aucun plat dans cette catégorie',
                        style: TextStyle(color: AppColors.textMuted))),
              ),
            ...shown.take(6).map((dish) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DishListCard(dish: dish),
                )),
          ],
        ),
      ),
    );
  }
}

/// Big photo card "Plat du jour" (same look as the mockup hero card).
class _FeaturedDishCard extends ConsumerWidget {
  const _FeaturedDishCard({required this.dish});
  final DishModel dish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => openDish(context, dish),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DishImage(url: dish.imagePath, name: dish.name, initialSize: 64),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.35, 1.0],
                    colors: [
                      Color(0x33000000),
                      Color(0x22000000),
                      Color(0xE61E140E),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2118).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          size: 14, color: Color(0xFFFFB27A)),
                      SizedBox(width: 5),
                      Text('Chef',
                          style: TextStyle(
                              color: Color(0xFFFFD8BC),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PLAT DU JOUR',
                              style: TextStyle(
                                  color: Color(0xFFFFA45C),
                                  fontSize: 11,
                                  letterSpacing: 0.6,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(dish.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(dish.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  height: 1.35)),
                          const SizedBox(height: 8),
                          Text(formatPrice(dish.price),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          ref.read(cartProvider.notifier).addToCart(dish.id!);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              duration: const Duration(seconds: 1),
                              content: Text('${dish.name} ajouté au panier')));
                        },
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu (explorer) ──────────────────────────────────────────────────────────

/// Full menu with search and category filter (client side).
class MenuExplorerTab extends ConsumerStatefulWidget {
  const MenuExplorerTab({super.key});

  @override
  ConsumerState<MenuExplorerTab> createState() => _MenuExplorerTabState();
}

class _MenuExplorerTabState extends ConsumerState<MenuExplorerTab> {
  final _searchCtrl = TextEditingController();
  List<DishModel>? _searchResults;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    final results = await ref.read(menuProvider.notifier).search(query.trim());
    if (mounted) setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(menuProvider);
    final displayDishes = _searchResults ?? state.filtered;
    final categories = DishModel.categories
        .where((c) => state.dishes.any((d) => d.category == c))
        .toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text('Menu',
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Rechercher un plat...',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textDark),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchResults = null);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          if (_searchResults == null && categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  CategoryChip(
                    label: 'Tout',
                    active: state.selectedCategory == null,
                    onTap: () =>
                        ref.read(menuProvider.notifier).setCategory(null),
                  ),
                  for (final c in categories) ...[
                    const SizedBox(width: 8),
                    CategoryChip(
                      label: c,
                      icon: categoryIcon(c),
                      active: state.selectedCategory == c,
                      onTap: () =>
                          ref.read(menuProvider.notifier).setCategory(c),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : displayDishes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                _searchResults != null
                                    ? Icons.search_off
                                    : Icons.no_food,
                                size: 64,
                                color: AppColors.border),
                            const SizedBox(height: 12),
                            Text(
                              _searchResults != null
                                  ? 'Aucun plat trouvé'
                                  : 'Menu indisponible',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        itemCount: displayDishes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            DishListCard(dish: displayDishes[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Standalone menu route (used by the integrated app: "Voir le menu").
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      body: Stack(
        children: [
          const MenuExplorerTab(),
          if (Navigator.of(context).canPop())
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
      floatingActionButton: cart.totalItems > 0
          ? FloatingActionButton.extended(
              heroTag: 'cart_fab',
              backgroundColor: AppColors.primary,
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CartScreen())),
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
              label: Text(
                  'Panier (${cart.totalItems}) · ${formatPrice(cart.totalPrice)}',
                  style: const TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}

// ── Shared pieces ────────────────────────────────────────────────────────────

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : AppColors.textDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: GoogleFonts.poppins(
                    color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Dish row card: photo, name, description, category, price, cart control.
class DishListCard extends ConsumerWidget {
  const DishListCard({super.key, required this.dish});
  final DishModel dish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider).quantityOf(dish.id!);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openDish(context, dish),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: DishImage(url: dish.imagePath, name: dish.name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dish.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text(dish.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: AppColors.textMuted)),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(formatPrice(dish.price),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.primary)),
                          ),
                          _CartControl(dish: dish, cartCount: cartCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartControl extends ConsumerWidget {
  const _CartControl({required this.dish, required this.cartCount});
  final DishModel dish;
  final int cartCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cartCount == 0) {
      return SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: 'Ajouter au panier',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          onPressed: () => ref.read(cartProvider.notifier).addToCart(dish.id!),
        ),
      );
    }
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.peach,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyIcon(
            icon: Icons.remove,
            onTap: () {
              final item = ref
                  .read(cartProvider)
                  .items
                  .where((ci) => ci.dishId == dish.id)
                  .firstOrNull;
              if (item != null) {
                ref
                    .read(cartProvider.notifier)
                    .updateQuantity(item.id!, item.quantity - 1);
              }
            },
          ),
          Text('$cartCount',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary)),
          _QtyIcon(
            icon: Icons.add,
            onTap: () => ref.read(cartProvider.notifier).addToCart(dish.id!),
          ),
        ],
      ),
    );
  }
}

class _QtyIcon extends StatelessWidget {
  const _QtyIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
            width: 30,
            height: 34,
            child: Icon(icon, size: 16, color: AppColors.primary)),
      );
}
