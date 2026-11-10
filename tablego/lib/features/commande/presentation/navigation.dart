import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/routes.dart';

/// Client shell tabs.
class ClientTab {
  static const home = 0, menu = 1, cart = 2, orders = 3;

  /// Module 3: table reservations + upcoming events of this restaurant.
  static const reserve = 4;

  /// Module 5: reviews + promotions of this restaurant.
  static const avis = 5;

  /// Module 4: anti-waste offers of this restaurant + my reservations.
  static const antiGaspi = 6;
}

/// Restaurant shell tabs.
class RestaurantTab {
  static const dishes = 0, assistant = 1, orders = 2;

  /// Module 3: requests, AI affluence, events.
  static const reservations = 3;

  /// Module 5: reviews (replies, spam) + promotions.
  static const avis = 4;

  /// Module 4: stock, waste log, anti-waste offers, AI.
  static const antiGaspi = 5;
  static const profile = 6;
}

final clientTabProvider = StateProvider<int>((ref) => ClientTab.home);
final restaurantTabProvider = StateProvider<int>((ref) => RestaurantTab.dishes);

/// Goes back to the client shell and selects [tab].
void goToClientTab(BuildContext context, WidgetRef ref, int tab) {
  ref.read(clientTabProvider.notifier).state = tab;
  Navigator.of(context).popUntil(
      (r) => r.settings.name == Routes.restaurantMenu || r.isFirst);
}

/// Leaves the restaurant being browsed ([ClientTab] shell) and returns to
/// the main client shell (Accueil · Explorer · Favoris · Activité · Profil).
void leaveRestaurant(BuildContext context) {
  Navigator.of(context).popUntil(
      (r) => r.settings.name == Routes.home || r.isFirst);
}

/// After an order: back to the main client shell, then its Activité screen
/// (Commandes tab), so the order is listed with every navigation option
/// (Profil, logout) one tap away.
void goToActivity(BuildContext context) {
  final navigator = Navigator.of(context);
  navigator.popUntil((r) => r.settings.name == Routes.home || r.isFirst);
  navigator.pushNamed(Routes.activity);
}
