class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String changePassword = '/auth/change-password';
  static const String deleteAccount = '/auth/account';

  // Profile
  static const String profile = '/profile/me';
  static const String clientProfile = '/profile/client';
  static const String restaurantProfile = '/profile/restaurant';
  static const String uploadPhoto = '/profile/upload-photo';

  // Favorites
  static const String favoriteRestaurants = '/favorites/restaurants';
  static const String favoriteDishes = '/favorites/dishes';

  // Recommendations
  static const String recommendations = '/recommendations';
}
