import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends ConsumerState<ChangePasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).changePassword(
          currentPassword: _currentCtrl.text,
          newPassword:     _newCtrl.text,
        );

    if (!mounted) return;
    final authState = ref.read(authProvider);

    if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.error!)),
      );
      ref.read(authProvider.notifier).clearError();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe modifié avec succès')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // isLoading comes from the notifier — no local setState needed.
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Changer le mot de passe')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Mot de passe actuel',
                controller: _currentCtrl,
                isPassword: true,
                prefixIcon: Icons.lock_outline,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Nouveau mot de passe',
                controller: _newCtrl,
                isPassword: true,
                prefixIcon: Icons.lock_reset_outlined,
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'Au moins 8 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Confirmer le nouveau mot de passe',
                controller: _confirmCtrl,
                isPassword: true,
                prefixIcon: Icons.lock_outline,
                validator: (v) {
                  if (v != _newCtrl.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Enregistrer',
                onPressed: _save,
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
