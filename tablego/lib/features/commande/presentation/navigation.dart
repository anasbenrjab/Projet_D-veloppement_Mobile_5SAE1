import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Client shell tabs.
class ClientTab {
  static const home = 0, menu = 1, cart = 2, orders = 3;
}

/// Restaurant shell tabs.
class RestaurantTab {
  static const dishes = 0, assistant = 1, orders = 2;
}

final clientTabProvider = StateProvider<int>((ref) => ClientTab.home);
final restaurantTabProvider = StateProvider<int>((ref) => RestaurantTab.dishes);

/// Goes back to the client shell and selects [tab].
void goToClientTab(BuildContext context, WidgetRef ref, int tab) {
  ref.read(clientTabProvider.notifier).state = tab;
  Navigator.of(context).popUntil(
      (r) => r.settings.name == '/client' || r.isFirst);
}
