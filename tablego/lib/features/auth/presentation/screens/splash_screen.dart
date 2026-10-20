import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Minimum splash display time runs in parallel with session restore.
    await Future.wait([
      Future<void>.delayed(const Duration(seconds: 2)),
      ref.read(authProvider.notifier).restoreSession(),
    ]);
    if (!mounted) return;

    final isLoggedIn = ref.read(authProvider).isLoggedIn;
    Navigator.of(context).pushReplacementNamed(
      isLoggedIn ? '/home' : '/login',
    );
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
