import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Upper bound on [AuthNotifier.restoreSession].
  ///
  /// A session restore must never leave the user stuck on the splash screen:
  /// when it exceeds this delay we log the failure and route to login instead.
  static const _restoreTimeout = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    // [restoreSession] mutates `authProvider`, and Riverpod forbids modifying a
    // provider while the widget tree is building — which is exactly what
    // `initState` runs in. Mutating there throws
    // "Tried to modify a provider while the widget tree was building"
    // (debug builds only), which made every session restore fail and always
    // land on the login screen. Defer to the end of the first frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final sw = Stopwatch()..start();
    if (kDebugMode) debugPrint('[Splash] _init: start');

    var restoreFailed = false;
    // Kept so the navigation log can report *what* failed, not just that it did.
    Object? restoreError;
    try {
      // Minimum splash display time runs in parallel with session restore.
      await Future.wait([
        Future<void>.delayed(const Duration(seconds: 2)),
        ref
            .read(authProvider.notifier)
            .restoreSession()
            .timeout(_restoreTimeout),
      ]);
    } on TimeoutException catch (e) {
      restoreFailed = true;
      restoreError = e;
      debugPrint('[Splash] restoreSession TIMED OUT after '
          '${_restoreTimeout.inSeconds}s — falling back to login '
          '(${sw.elapsedMilliseconds}ms): ${e.runtimeType}: $e');
    } catch (e, st) {
      restoreFailed = true;
      restoreError = e;
      debugPrint('[Splash] restoreSession threw after '
          '${sw.elapsedMilliseconds}ms — falling back to login: '
          '${e.runtimeType}: $e\n$st');
    }

    if (!mounted) return;

    final isLoggedIn = !restoreFailed && ref.read(authProvider).isLoggedIn;
    final target = isLoggedIn ? Routes.home : Routes.login;
    if (kDebugMode) {
      final errorDetail = restoreError == null
          ? ''
          : ', error=${restoreError.runtimeType}: $restoreError';
      debugPrint('[Splash] navigating to $target '
          '(${sw.elapsedMilliseconds}ms, restoreFailed=$restoreFailed'
          '$errorDetail)');
    }
    Navigator.of(context).pushReplacementNamed(target);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu,
                color: Colors.white, size: 72),
            const SizedBox(height: 20),
            const Text(
              'TableGo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Découvrez, commandez, savourez',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
            ),
            const SizedBox(height: 60),
            const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
