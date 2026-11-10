import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_model.dart';
import '../../providers/order_provider.dart';
import 'order_detail_screen.dart';

/// Client-side: view all my orders and their status.
class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key, this.standalone = true});
  final bool standalone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderProvider);

    final body = state.isLoading
        ? const Center(child: CircularProgressIndicator())
        : state.orders.isEmpty
            ? _EmptyHistory()
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(orderProvider.notifier).loadOrders(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.orders.length,
                  itemBuilder: (_, i) =>
                      _OrderTile(order: state.orders[i]),
                ),
              );

    if (!standalone) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes commandes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(orderProvider.notifier).loadOrders(),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});
  final OrderModel order;

  Color _statusColor(String status) {
    switch (status) {
      case OrderStatus.received:
        return AppColors.rating;
      case OrderStatus.preparing:
        return AppColors.primary;
      case OrderStatus.ready:
        return AppColors.eco;
      default:
        return AppColors.grey500;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case OrderStatus.received:
        return Icons.receipt_long;
      case OrderStatus.preparing:
        return Icons.soup_kitchen;
      case OrderStatus.ready:
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: order.id!)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon(order.status),
                        color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Commande #${order.id}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(
                          _formatDate(order.createdAt),
                          style: const TextStyle(
                              color: AppColors.grey500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${order.totalPrice.toStringAsFixed(3)} DT',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 15),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.status,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text(
                  order.items
                      .map((i) => '${i.dishName} ×${i.quantity}')
                      .join(', '),
                  style: const TextStyle(
                      color: AppColors.grey700, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Order type badge
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    order.orderType == OrderType.dineIn
                        ? Icons.table_restaurant
                        : Icons.takeout_dining,
                    size: 14,
                    color: AppColors.grey500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.orderType == OrderType.dineIn
                        ? 'Sur place'
                        : 'À emporter',
                    style: const TextStyle(
                        color: AppColors.grey500, fontSize: 12),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: AppColors.grey300, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 80, color: AppColors.grey300),
          const SizedBox(height: 16),
          const Text('Aucune commande',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Vos commandes apparaîtront ici.',
              style: TextStyle(color: AppColors.grey500)),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed('/menu'),
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Voir le menu'),
          ),
        ],
      ),
    );
  }
}
