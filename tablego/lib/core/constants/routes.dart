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
}
