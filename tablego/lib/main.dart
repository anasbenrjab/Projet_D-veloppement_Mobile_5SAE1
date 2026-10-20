import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/change_password_screen.dart';
import 'features/auth/presentation/screens/client_home_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/profile/presentation/screens/client_profile_screen.dart';
import 'features/profile/presentation/screens/edit_client_profile_screen.dart';
import 'features/profile/presentation/screens/restaurant_profile_screen.dart';
import 'features/profile/presentation/screens/edit_restaurant_profile_screen.dart';
import 'features/favorites/presentation/screens/favorites_screen.dart';

void main() {
  runApp(const ProviderScope(child: TableGoApp()));
}

class TableGoApp extends StatelessWidget {
  const TableGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TableGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: Routes.splash,
      routes: {
        Routes.splash:                (_) => const SplashScreen(),
        Routes.login:                 (_) => const LoginScreen(),
        Routes.register:              (_) => const RegisterScreen(),
        Routes.forgotPassword:        (_) => const ForgotPasswordScreen(),
        Routes.changePassword:        (_) => const ChangePasswordScreen(),
        Routes.home:                  (_) => const ClientHomeScreen(),
        Routes.profile:               (_) => const _ProfileRouter(),
        Routes.editClientProfile:     (_) => const EditClientProfileScreen(),
        Routes.restaurantProfile:     (_) => const RestaurantProfileScreen(),
        Routes.editRestaurantProfile: (_) => const EditRestaurantProfileScreen(),
        Routes.favorites:             (_) => const FavoritesScreen(),
      },
    );
  }
}

/// Routes to [ClientProfileScreen] or [RestaurantProfileScreen] based on
/// the authenticated user's [userType].
class _ProfileRouter extends ConsumerWidget {
  const _ProfileRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userType = ref.watch(authProvider).user?.userType;
    return userType == 'restaurant'
        ? const RestaurantProfileScreen()
        : const ClientProfileScreen();
  }
}
