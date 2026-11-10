import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/widgets/dish_image.dart';
import '../../providers/dish_provider.dart';
import '../../data/models/dish_model.dart';
import 'add_edit_dish_screen.dart';
import 'menu_screen.dart' show formatPrice;

/// Restaurant side — "Mes plats": CRUD list of dishes grouped by category.
/// The bottom navigation lives in the RestaurantShell (main.dart).
class ManageDishesScreen extends ConsumerStatefulWidget {
  const ManageDishesScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<ManageDishesScreen> createState() =>
      _ManageDishesScreenState();
}

class _ManageDishesScreenState extends ConsumerState<ManageDishesScreen> {
  @override
  Widget build(BuildContext context) {
    final count = ref.watch(dishProvider).dishes.length;
    final content = SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mes plats',
                          style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      Text('$count plat${count > 1 ? 's' : ''} à la carte',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser',
                  icon: const Icon(Icons.refresh, color: AppColors.textMuted),
                  onPressed: () => ref.read(dishProvider.notifier).loadAll(),
                ),
              ],
            ),
          ),
          const Expanded(child: _DishesTab()),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_dish',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditDishScreen()),
        ),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter un plat',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ── Dishes tab ─────────────────────────────────────────────────────────────

class _DishesTab extends ConsumerWidget {
  const _DishesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dishProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(state.error!,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(dishProvider.notifier).loadAll(),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (state.dishes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: AppColors.grey300),
            const SizedBox(height: 16),
            const Text('Aucun plat pour l\'instant',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Appuyez sur + pour ajouter votre premier plat.',
                style: TextStyle(color: AppColors.grey500)),
          ],
        ),
      );
    }

    // Group by category
    final grouped = <String, List<DishModel>>{};
    for (final d in state.dishes) {
      (grouped[d.category] ??= []).add(d);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(entry.key,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ),
            ...entry.value.map((dish) => _DishTile(dish: dish)),
          ],
        );
      }).toList(),
    );
  }
}

class _DishTile extends ConsumerWidget {
  const _DishTile({required this.dish});
  final DishModel dish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Opacity(
                opacity: dish.isAvailable ? 1 : 0.4,
                child: DishImage(
                    url: dish.imagePath, name: dish.name, initialSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dish.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(formatPrice(dish.price),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(dish.isAvailable ? 'Disponible' : 'Indisponible',
                    style: TextStyle(
                        fontSize: 11,
                        color: dish.isAvailable
                            ? AppColors.eco
                            : AppColors.textMuted)),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: FittedBox(
              child: Switch(
                value: dish.isAvailable,
                activeTrackColor: AppColors.eco,
                onChanged: (val) => ref
                    .read(dishProvider.notifier)
                    .toggleAvailability(dish.id!, val),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Modifier',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AddEditDishScreen(dish: dish)),
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le plat'),
        content: Text('Voulez-vous supprimer « ${dish.name} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(dishProvider.notifier).deleteDish(dish.id!);
              Navigator.pop(context);
            },
            child: const Text('Supprimer',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
