import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/dish_image.dart';
import '../../providers/cart_provider.dart';
import '../../data/models/cart_item_model.dart';
import 'checkout_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key, this.standalone = true, this.onBrowseMenu});

  /// false when shown as the "Panier" tab of the client shell.
  final bool standalone;
  final VoidCallback? onBrowseMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartProvider);

    final body = state.isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary))
        : state.items.isEmpty
            ? _EmptyCart(
                onBrowse: onBrowseMenu ?? () => Navigator.of(context).pop())
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      itemCount: state.items.length,
                      itemBuilder: (_, i) =>
                          _CartItemTile(item: state.items[i]),
                    ),
                  ),
                  _CartSummary(state: state),
                ],
              );

    final clearButton = state.items.isEmpty
        ? null
        : TextButton.icon(
            onPressed: () => _confirmClear(context, ref),
            icon: const Icon(Icons.delete_sweep_outlined,
                color: AppColors.error, size: 20),
            label:
                const Text('Vider', style: TextStyle(color: AppColors.error)),
          );

    if (!standalone) {
      return SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Mon panier',
                        style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                  ),
                  if (clearButton != null) clearButton,
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon panier'),
        actions: [if (clearButton != null) clearButton],
      ),
      body: body,
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vider le panier'),
        content: const Text('Supprimer tous les articles du panier ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            child: const Text('Vider',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});
  final CartItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dish = item.dish;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 60,
                height: 60,
                child: DishImage(
                    url: dish?.imagePath,
                    name: dish?.name ?? '?',
                    initialSize: 22),
              ),
            ),
            const SizedBox(width: 12),

            // Name + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish?.name ?? 'Plat supprimé',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(dish?.price ?? 0).toStringAsFixed(3)} DT × ${item.quantity} = ${item.subtotal.toStringAsFixed(3)} DT',
                    style: const TextStyle(
                        color: AppColors.grey500, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Quantity controls
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    item.quantity <= 1
                        ? Icons.delete_outline
                        : Icons.remove,
                    color: item.quantity <= 1
                        ? AppColors.error
                        : AppColors.grey700,
                    size: 20,
                  ),
                  onPressed: () => ref
                      .read(cartProvider.notifier)
                      .updateQuantity(item.id!, item.quantity - 1),
                ),
                Text('${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add,
                      color: AppColors.primary, size: 20),
                  onPressed: () => ref
                      .read(cartProvider.notifier)
                      .updateQuantity(item.id!, item.quantity + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.state});
  final CartState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.totalItems} article${state.totalItems > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: AppColors.grey500, fontSize: 14),
              ),
              Text(
                '${state.totalPrice.toStringAsFixed(3)} DT',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Passer la commande',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CheckoutScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
                color: AppColors.peach, shape: BoxShape.circle),
            child: const Icon(Icons.shopping_bag_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('Votre panier est vide',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Ajoutez des plats depuis le menu.',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.restaurant_menu, color: AppColors.primary),
            label: const Text('Voir le menu',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
