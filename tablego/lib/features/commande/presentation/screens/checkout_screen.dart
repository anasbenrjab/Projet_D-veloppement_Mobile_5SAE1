import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/models/order_model.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import 'order_confirmation_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _orderType = OrderType.dineIn;
  // Prefilled with the logged-in client's name (Module 1 profile).
  late final _nameCtrl = TextEditingController(text: _profileName());

  String _profileName() {
    final data = ref.read(profileProvider).data;
    final name = data is ClientData ? data.profile.fullName?.trim() : null;
    return (name == null || name.isEmpty) ? 'Client' : name;
  }
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final cartItems = ref.read(cartProvider).items;
    if (cartItems.isEmpty) return;

    final order = await ref.read(orderProvider.notifier).placeOrder(
          cartItems: cartItems,
          orderType: _orderType,
          note: _noteCtrl.text.trim(),
          clientName: _nameCtrl.text.trim().isEmpty
              ? 'Client'
              : _nameCtrl.text.trim(),
        );

    if (order != null && mounted) {
      // Cart is already cleared by the provider
      ref.read(cartProvider.notifier).loadCart();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => OrderConfirmationScreen(order: order)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final orderState = ref.watch(orderProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Passer la commande')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Order type selector
          const Text('Type de commande',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: OrderType.all.map((type) {
              final selected = _orderType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _orderType = type),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: type == OrderType.dineIn ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.grey100,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? null
                          : Border.all(color: AppColors.grey300),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          type == OrderType.dineIn
                              ? Icons.table_restaurant
                              : Icons.takeout_dining,
                          color: selected
                              ? Colors.white
                              : AppColors.grey700,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type == OrderType.dineIn
                              ? 'Sur place'
                              : 'À emporter',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.grey700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Name
          AppTextField(
            label: 'Votre prénom',
            hint: 'Ex: Roudaina',
            controller: _nameCtrl,
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),

          // Note
          AppTextField(
            label: 'Note pour le restaurant',
            hint: 'Ex: sans oignons, allergie aux noix...',
            controller: _noteCtrl,
            prefixIcon: Icons.notes,
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Order summary
          const Text('Récapitulatif',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  ...cartState.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.dish?.name ?? '?'} × ${item.quantity}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            '${item.subtotal.toStringAsFixed(3)} DT',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(
                        '${cartState.totalPrice.toStringAsFixed(3)} DT',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          if (orderState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(orderState.error!,
                  style:
                      const TextStyle(color: AppColors.error)),
            ),

          AppButton(
            label: 'Confirmer la commande',
            onPressed: _placeOrder,
            isLoading: orderState.isLoading,
          ),
        ],
      ),
    );
  }
}
