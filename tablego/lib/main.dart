import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/change_password_screen.dart';
import 'features/auth/presentation/screens/client_home_screen.dart';
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
      initialRoute: '/',
      routes: {
        '/':                          (_) => const SplashScreen(),
        '/login':                     (_) => const LoginScreen(),
        '/register':                  (_) => const RegisterScreen(),
        '/forgot-password':           (_) => const ForgotPasswordScreen(),
        '/change-password':           (_) => const ChangePasswordScreen(),
        '/home':                      (_) => const ClientHomeScreen(),
        '/profile':                   (_) => const _ProfileRouter(),
        '/edit-client-profile':       (_) => const EditClientProfileScreen(),
        '/restaurant-profile':        (_) => const RestaurantProfileScreen(),
        '/edit-restaurant-profile':   (_) => const EditRestaurantProfileScreen(),
        '/favorites':                 (_) => const FavoritesScreen(),
      },
    );
  }
}

/// Routes to client or restaurant profile based on stored user data.
/// For Module 1, defaults to ClientProfileScreen.
class _ProfileRouter extends ConsumerWidget {
  const _ProfileRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ClientProfileScreen();
  }
}
