import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/dish_model.dart';
import '../../data/repositories/dish_repository.dart';
import '../../../commande/providers/cart_provider.dart';
import '../../../../shared/widgets/dish_image.dart';
import '../../services/meal_db_service.dart';

/// "Ailleurs dans le monde" — recipes similar to this dish from TheMealDB,
/// with origin and ingredients (tap to expand).
class _SimilarRecipes extends ConsumerWidget {
  const _SimilarRecipes({required this.dishName});
  final String dishName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(similarRecipesProvider(dishName));
    return recipes.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(
            color: AppColors.primary, backgroundColor: AppColors.peach),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.public, size: 18, color: AppColors.primary),
                SizedBox(width: 6),
                Text('Ailleurs dans le monde',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Text('Recettes similaires · source TheMealDB',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            ...list.take(3).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Image.network(m.preview,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: AppColors.peach)),
                        ),
                      ),
                      title: Text(m.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('${m.area} · ${m.category}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ingrédients',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: m.ingredients
                              .map((i) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Text(i,
                                        style: const TextStyle(fontSize: 11)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ))),
          ],
        );
      },
    );
  }
}

class DishDetailScreen extends ConsumerStatefulWidget {
  const DishDetailScreen({super.key, required this.dishId});
  final int dishId;

  @override
  ConsumerState<DishDetailScreen> createState() =>
      _DishDetailScreenState();
}

class _DishDetailScreenState extends ConsumerState<DishDetailScreen> {
  DishModel? _dish;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDish();
  }

  Future<void> _loadDish() async {
    final repo = DishRepository(DatabaseHelper.instance);
    final dish = await repo.getDishById(widget.dishId);
    if (mounted) setState(() {
      _dish = dish;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_dish == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Plat introuvable')),
      );
    }

    final dish = _dish!;
    final cartState = ref.watch(cartProvider);
    final qty = cartState.quantityOf(dish.id!);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      size: 18, color: AppColors.textDark),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: DishImage(
                  url: dish.imagePath, name: dish.name, initialSize: 100),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(dish.name,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        '${dish.price.toStringAsFixed(3)} DT',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(dish.category,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (dish.description.isNotEmpty) ...[
                    const Text('Description',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(dish.description,
                        style: const TextStyle(
                            color: AppColors.grey700,
                            fontSize: 14,
                            height: 1.5)),
                    const SizedBox(height: 16),
                  ],

                  // Allergens
                  if (dish.allergens.isNotEmpty) ...[
                    const Text('Allergènes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: dish.allergens
                          .split(',')
                          .map((a) => a.trim())
                          .where((a) => a.isNotEmpty)
                          .map(
                            (a) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: a == 'Aucun'
                                    ? AppColors.eco.withOpacity(0.1)
                                    : AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(a,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: a == 'Aucun'
                                          ? AppColors.eco
                                          : AppColors.error,
                                      fontWeight: FontWeight.w500)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Similar recipes worldwide (TheMealDB external API)
                  _SimilarRecipes(dishName: dish.name),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: qty == 0
              ? AppButton(
                  label: 'Ajouter au panier',
                  onPressed: () {
                    ref
                        .read(cartProvider.notifier)
                        .addToCart(dish.id!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${dish.name} ajouté au panier !'),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                )
              : Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () {
                        final cart = ref.read(cartProvider);
                        final item = cart.items
                            .where((ci) => ci.dishId == dish.id)
                            .firstOrNull;
                        if (item != null) {
                          ref
                              .read(cartProvider.notifier)
                              .updateQuantity(item.id!, item.quantity - 1);
                        }
                      },
                    ),
                    Expanded(
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$qty dans le panier',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () => ref
                          .read(cartProvider.notifier)
                          .addToCart(dish.id!),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.only(right: 8, left: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}
