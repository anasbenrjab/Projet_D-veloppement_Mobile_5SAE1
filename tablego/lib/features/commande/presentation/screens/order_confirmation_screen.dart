import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../navigation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/order_model.dart';

class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.eco.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    size: 60, color: AppColors.eco),
              ),
              const SizedBox(height: 24),

              const Text('Commande passée !',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Text(
                'Commande #${order.id}',
                style: const TextStyle(
                    fontSize: 16, color: AppColors.grey500),
              ),
              const SizedBox(height: 28),

              // Details card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: order.orderType == OrderType.dineIn
                            ? Icons.table_restaurant
                            : Icons.takeout_dining,
                        label: 'Type',
                        value: order.orderType == OrderType.dineIn
                            ? 'Sur place'
                            : 'À emporter',
                      ),
                      const Divider(height: 16),
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Nom',
                        value: order.clientName,
                      ),
                      const Divider(height: 16),
                      _DetailRow(
                        icon: Icons.monetization_on_outlined,
                        label: 'Total',
                        value:
                            '${order.totalPrice.toStringAsFixed(3)} DT',
                      ),
                      const Divider(height: 16),
                      _DetailRow(
                        icon: Icons.hourglass_empty,
                        label: 'Statut',
                        value: order.status,
                        valueColor: AppColors.rating,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (order.note.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notes,
                          color: AppColors.grey500, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(order.note,
                              style: const TextStyle(
                                  color: AppColors.grey700,
                                  fontSize: 13))),
                    ],
                  ),
                ),

              const SizedBox(height: 36),

              AppButton(
                label: 'Voir mes commandes',
                onPressed: () {
                  goToClientTab(context, ref, ClientTab.orders);
                },
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Retour au menu',
                isOutlined: true,
                onPressed: () {
                  goToClientTab(context, ref, ClientTab.menu);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.grey500),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppColors.grey500, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: valueColor ?? AppColors.textDark)),
      ],
    );
  }
}
