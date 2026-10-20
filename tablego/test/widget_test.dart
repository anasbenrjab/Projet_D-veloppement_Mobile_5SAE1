// Smoke test: the app boots, shows the splash screen, then routes to the
// login screen when no local session exists.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tablego/features/auth/data/models/user_model.dart';
import 'package:tablego/features/auth/data/repositories/auth_repository.dart';
import 'package:tablego/features/auth/providers/auth_provider.dart';
import 'package:tablego/main.dart';

/// Stub repository that reports "no session" without touching sqflite or
/// secure storage (neither is available in a plain widget test).
class _NoSessionRepository extends AuthRepository {
  @override
  Future<UserModel?> getSessionUser() async => null;
}

/// Stub notifier whose [restoreSession] does nothing synchronously.
///
/// [SplashScreen] calls `restoreSession()` from `initState`; the real
/// implementation sets state eagerly, which trips Riverpod's
/// "modify a provider while the widget tree is building" guard in tests.
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier() : super(_NoSessionRepository());

  @override
  Future<void> restoreSession() async {}
}

void main() {
  setUpAll(() {
    // Never hit the network / path_provider for fonts during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('boots to the login screen when there is no session',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _StubAuthNotifier()),
        ],
        child: const TableGoApp(),
      ),
    );

    // Splash is shown first.
    expect(find.text('TableGo'), findsOneWidget);

    // Let the splash timer finish and the session check resolve.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Lands on the login screen.
    expect(find.text('Bienvenue 👋'), findsOneWidget);
  });
}
