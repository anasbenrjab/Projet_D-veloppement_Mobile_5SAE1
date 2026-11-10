/// Central route names for the app's [Navigator].
///
/// Use these constants instead of hard-coded strings in `pushNamed` calls and
/// in the `MaterialApp.routes` map, so a route rename is a single-point change.
class Routes {
  Routes._();

  static const String splash               = '/';
  static const String login                = '/login';
  static const String register             = '/register';
  static const String forgotPassword       = '/forgot-password';
  static const String changePassword       = '/change-password';
  static const String home                 = '/home';
  static const String profile              = '/profile';
  static const String editClientProfile    = '/edit-client-profile';
  static const String restaurantProfile    = '/restaurant-profile';
  static const String editRestaurantProfile = '/edit-restaurant-profile';
  static const String favorites            = '/favorites';

  // Module 2 — menu + commande
  static const String restaurants          = '/restaurants';
  static const String restaurantMenu       = '/restaurant-menu';
  static const String restaurantHome       = '/restaurant';
  static const String activity             = '/activity';

  // Module 3 — événements + réservations: tabs of the shells above and of
  // the client activity screen (no routes of their own).

  // Module 5 — avis + promotions: « Avis » tab of both shells, plus its forms
  // (route names kept from Module 5, used with pushNamed + arguments).
  static const String ajoutAvis            = '/ajoutAvis';
  static const String ajoutPromotion       = '/ajoutPromotion';
  static const String codePromo            = '/codePromo';

  /// Landing route for an authenticated user: restaurant accounts go to
  /// their restaurant space (dishes, orders, profile…), everyone else to the
  /// client home.
  static String homeFor(String? userType) =>
      userType == 'restaurant' ? restaurantHome : home;
}
