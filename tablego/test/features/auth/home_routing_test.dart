// Role-based landing route: restaurant accounts must not land on the client
// home (which loads a client profile and fails for them).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tablego/core/constants/routes.dart';
import 'package:tablego/features/auth/data/models/user_model.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/auth/providers/auth_provider.dart';
import 'package:tablego/features/profile/data/models/restaurant_profile_model.dart';
import 'package:tablego/features/profile/data/repositories/profile_repository.dart';
import 'package:tablego/features/profile/domain/profile_exception.dart';
import 'package:tablego/main.dart';

const _restaurantUser = UserModel(
  id: 7,
  email: 'resto@test.com',
  userType: 'restaurant',
  isActive: true,
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-01-01T00:00:00Z',
);

/// Restores a restaurant session without touching sqflite or secure storage.
class _RestaurantSessionNotifier extends AuthNotifier {
  _RestaurantSessionNotifier() : super(AuthRepository());

  @override
  Future<void> restoreSession() async {
    state = state.copyWith(user: _restaurantUser);
  }
}

/// Avoids the real database; the screen still renders its app bar.
class _StubProfileRepository extends ProfileRepository {
  @override
  Future<RestaurantProfileModel> getRestaurantProfile(int userId) async =>
      throw const ProfileException('stub');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Routes.homeFor', () {
    test('restaurant → restaurant screen', () {
      expect(Routes.homeFor('restaurant'), Routes.restaurantProfile);
    });

    test('client → client home', () {
      expect(Routes.homeFor('client'), Routes.home);
    });

    test('unknown / null → client home', () {
      expect(Routes.homeFor(null), Routes.home);
    });
  });

  testWidgets('splash sends a restored restaurant session to its screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _RestaurantSessionNotifier()),
          profileRepositoryProvider
              .overrideWithValue(_StubProfileRepository()),
        ],
        child: const TableGoApp(),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Mon restaurant'), findsOneWidget);
    expect(find.text('Que voulez-vous manger ?'), findsNothing);
  });
}
