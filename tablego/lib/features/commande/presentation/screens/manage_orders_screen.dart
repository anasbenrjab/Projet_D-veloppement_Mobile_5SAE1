import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_model.dart';
import '../../providers/order_provider.dart';

/// Restaurant-side screen: view and update order statuses.
class ManageOrdersScreen extends ConsumerStatefulWidget {
  const ManageOrdersScreen({super.key, this.standalone = true});
  final bool standalone;

  @override
  ConsumerState<ManageOrdersScreen> createState() =>
      _ManageOrdersScreenState();
}

class _ManageOrdersScreenState
    extends ConsumerState<ManageOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When embedded (standalone: false), skip the Scaffold and show content directly
    if (!widget.standalone) {
      return Column(
        children: [
          // Refresh button row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                const Text('Reçue → En préparation → Prête',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () =>
                      ref.read(orderProvider.notifier).loadOrders(),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Reçues'),
              Tab(text: 'En préparation'),
              Tab(text: 'Prêtes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OrderTab(status: OrderStatus.received),
                _OrderTab(status: OrderStatus.preparing),
                _OrderTab(status: OrderStatus.ready),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des commandes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(orderProvider.notifier).loadOrders(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Reçues'),
            Tab(text: 'En préparation'),
            Tab(text: 'Prêtes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OrderTab(status: OrderStatus.received),
          _OrderTab(status: OrderStatus.preparing),
          _OrderTab(status: OrderStatus.ready),
        ],
      ),
    );
  }
}

class _OrderTab extends ConsumerWidget {
  const _OrderTab({required this.status});
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderProvider);
    final orders =
        state.orders.where((o) => o.status == status).toList();

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_statusIcon(status), size: 64, color: AppColors.grey300),
            const SizedBox(height: 12),
            Text('Aucune commande $status',
                style: const TextStyle(
                    color: AppColors.grey500, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(orderProvider.notifier).loadOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (_, i) => _RestaurantOrderCard(order: orders[i]),
      ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case OrderStatus.received:
        return Icons.inbox;
      case OrderStatus.preparing:
        return Icons.soup_kitchen;
      case OrderStatus.ready:
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }
}

class _RestaurantOrderCard extends ConsumerWidget {
  const _RestaurantOrderCard({required this.order});
  final OrderModel order;

  String _nextLabel(String current) {
    switch (current) {
      case OrderStatus.received:
        return 'Mettre en préparation';
      case OrderStatus.preparing:
        return 'Marquer comme prête';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAdvance = order.status != OrderStatus.ready;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text('Commande #${order.id}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: order.orderType == OrderType.dineIn
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.eco.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.orderType == OrderType.dineIn
                        ? 'Sur place'
                        : 'À emporter',
                    style: TextStyle(
                        color: order.orderType == OrderType.dineIn
                            ? AppColors.primary
                            : AppColors.eco,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${order.clientName}  •  ${_formatDate(order.createdAt)}',
              style: const TextStyle(
                  color: AppColors.grey500, fontSize: 13),
            ),

            const Divider(height: 16),

            // Items
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record,
                        size: 8, color: AppColors.grey500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('${item.dishName} × ${item.quantity}',
                          style: const TextStyle(fontSize: 14)),
                    ),
                    Text(
                      '${item.subtotal.toStringAsFixed(3)} DT',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            if (order.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.rating.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notes,
                        size: 14, color: AppColors.rating),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(order.note,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.grey700))),
                  ],
                ),
              ),
            ],

            const Divider(height: 16),

            // Total + action button
            Row(
              children: [
                Text(
                  'Total: ${order.totalPrice.toStringAsFixed(3)} DT',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary),
                ),
                const Spacer(),
                if (canAdvance)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      // The theme sets an infinite min width (full-width
                      // buttons); inside a Row that must be overridden.
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => ref
                        .read(orderProvider.notifier)
                        .advanceStatus(order.id!),
                    child: Text(
                      _nextLabel(order.status),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
