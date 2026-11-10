import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/routes.dart';
import 'core/database/web_database_factory.dart';
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
import 'features/commande/presentation/screens/module2_shells.dart';
import 'features/activity/presentation/activity_screen.dart';
import 'features/menu/presentation/screens/restaurants_screen.dart';

void main() {
  final bootWatch = Stopwatch()..start();
  if (kDebugMode) debugPrint('[Boot] main() start');
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugPrint('[Boot] engine ready (${bootWatch.elapsedMilliseconds}ms)');
  }
  // On web this switches sqflite to the sqlite3-wasm factory; it is a no-op on
  // mobile (see the conditional import).  Must run before the DB is opened.
  configureWebDatabaseFactory();
  if (kDebugMode) debugPrint('[Boot] runApp() (${bootWatch.elapsedMilliseconds}ms)');
  runApp(const ProviderScope(child: TableGoApp()));
}

class TableGoApp extends StatelessWidget {
  const TableGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TableGo',
      debugShowCheckedModeBanner: false,
      // French Material widgets (date pickers…); English as a fallback.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Screens still use fixed light colours (AppColors); dark mode stays off
      // until they read from the colour scheme.
      themeMode: ThemeMode.light,
      initialRoute: Routes.splash,
      // Routes that take arguments.
      onGenerateRoute: (settings) => switch (settings.name) {
        Routes.restaurantMenu => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ClientShell(
                args: settings.arguments! as RestaurantMenuArgs),
          ),
        _ => null,
      },
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
        // Module 2 — menu + commande
        Routes.restaurants:           (_) => const RestaurantsScreen(),
        Routes.restaurantHome:        (_) => const RestaurantShell(),
        Routes.activity:              (_) => const ActivityScreen(),
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
