import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';

/// Two-step password reset using a security question.
///
/// Step 1 — user enters their email → [AuthNotifier.getResetQuestion] is
///   called.  On success [AuthState.resetQuestion] is populated and the
///   screen advances to step 2.
///
/// Step 2 — the security question is displayed; user enters their answer
///   and a new password → [AuthNotifier.resetPassword] is called.  On
///   success the screen shows a confirmation and returns to login.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  // ── Step 1 ────────────────────────────────────────────────────────────────
  final _step1Key  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  // ── Step 2 ────────────────────────────────────────────────────────────────
  final _step2Key    = GlobalKey<FormState>();
  final _answerCtrl  = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _done = false; // true once reset succeeds

  @override
  void dispose() {
    _emailCtrl.dispose();
    _answerCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _submitEmail() async {
    if (!_step1Key.currentState!.validate()) return;
    await ref
        .read(authProvider.notifier)
        .getResetQuestion(_emailCtrl.text.trim());
    // Navigation is driven by build() watching resetQuestion / error.
  }

  Future<void> _submitReset() async {
    if (!_step2Key.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).resetPassword(
          email:       _emailCtrl.text.trim(),
          answer:      _answerCtrl.text,
          newPassword: _newPassCtrl.text,
        );
    if (success && mounted) setState(() => _done = true);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState     = ref.watch(authProvider);
    final isLoading     = authState.isLoading;
    final resetQuestion = authState.resetQuestion;

    // Show inline error via SnackBar when it changes.
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _done
              ? _successView()
              : (resetQuestion == null
                  ? _step1View(isLoading: isLoading)
                  : _step2View(
                      question: resetQuestion, isLoading: isLoading)),
        ),
      ),
    );
  }

  // ── Step 1 widget ─────────────────────────────────────────────────────────

  Widget _step1View({required bool isLoading}) => Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.lock_reset, size: 60, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'Réinitialiser le mot de passe',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Entrez votre email pour retrouver votre question de sécurité.',
              style: TextStyle(fontSize: 14, color: AppColors.grey500),
            ),
            const SizedBox(height: 32),
            AppTextField(
              label: 'Email',
              hint: 'votre@email.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Format d\'email invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Continuer',
              onPressed: _submitEmail,
              isLoading: isLoading,
            ),
          ],
        ),
      );

  // ── Step 2 widget ─────────────────────────────────────────────────────────

  Widget _step2View({
    required String question,
    required bool isLoading,
  }) =>
      Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.help_outline,
                size: 60, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'Question de sécurité',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Display the question in a card so it's visually distinct.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                question,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Votre réponse',
              controller: _answerCtrl,
              prefixIcon: Icons.vpn_key_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Réponse requise' : null,
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Nouveau mot de passe',
              controller: _newPassCtrl,
              isPassword: true,
              prefixIcon: Icons.lock_outline,
              validator: (v) {
                if (v == null || v.length < 8) {
                  return 'Au moins 8 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Confirmer le mot de passe',
              controller: _confirmCtrl,
              isPassword: true,
              prefixIcon: Icons.lock_outline,
              validator: (v) {
                if (v != _newPassCtrl.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Réinitialiser',
              onPressed: _submitReset,
              isLoading: isLoading,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  // Let the user correct their email — go back to step 1.
                  ref.read(authProvider.notifier).clearError();
                  // Clear resetQuestion in state by calling clearError +
                  // rebuilding; a dedicated clearResetQuestion action would
                  // be cleaner but is not worth the added complexity here.
                  ref.read(authProvider.notifier).clearResetQuestion();
                },
                child: const Text(
                  'Utiliser un autre email',
                  style: TextStyle(color: AppColors.grey500),
                ),
              ),
            ),
          ],
        ),
      );

  // ── Success widget ────────────────────────────────────────────────────────

  Widget _successView() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.check_circle_outline,
              size: 80, color: AppColors.eco),
          const SizedBox(height: 24),
          const Text(
            'Mot de passe réinitialisé !',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
            style: TextStyle(fontSize: 14, color: AppColors.grey500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          AppButton(
            label: 'Retour à la connexion',
            onPressed: () => Navigator.of(context)
                .pushReplacementNamed('/login'),
          ),
        ],
      );
}
