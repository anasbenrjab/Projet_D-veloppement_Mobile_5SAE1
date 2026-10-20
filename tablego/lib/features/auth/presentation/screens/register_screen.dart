import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';

const _kSecurityQuestions = [
  'Quel est le prénom de votre mère ?',
  'Quel est le nom de votre premier animal de compagnie ?',
  'Dans quelle ville êtes-vous né(e) ?',
  'Quel est le nom de votre école primaire ?',
  'Quel était le modèle de votre première voiture ?',
];

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _answerCtrl    = TextEditingController();
  final _restNameCtrl  = TextEditingController();

  String  _userType        = 'client';
  String  _selectedQuestion = _kSecurityQuestions.first;
  bool    _acceptTerms     = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _answerCtrl.dispose();
    _restNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez accepter les conditions d\'utilisation')),
      );
      return;
    }

    await ref.read(authProvider.notifier).register(
          email:          _emailCtrl.text.trim(),
          password:       _passCtrl.text,
          userType:       _userType,
          resetQuestion:  _selectedQuestion,
          resetAnswer:    _answerCtrl.text,
          restaurantName: _userType == 'restaurant'
              ? _restNameCtrl.text.trim()
              : null,
        );

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (authState.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(authState.error!)));
      ref.read(authProvider.notifier).clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── User type toggle ────────────────────────────────────────
                const Text('Vous êtes :',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _TypeTab(
                        label: 'Client',
                        icon: Icons.person_outline,
                        selected: _userType == 'client',
                        onTap: () => setState(() => _userType = 'client'),
                      ),
                      _TypeTab(
                        label: 'Restaurant',
                        icon: Icons.store_outlined,
                        selected: _userType == 'restaurant',
                        onTap: () =>
                            setState(() => _userType = 'restaurant'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Restaurant name (only when userType = restaurant) ────────
                if (_userType == 'restaurant') ...[
                  AppTextField(
                    label: 'Nom du restaurant',
                    hint: 'Le Gourmet Parisien',
                    controller: _restNameCtrl,
                    prefixIcon: Icons.store_outlined,
                    validator: (v) {
                      if (_userType != 'restaurant') return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Le nom du restaurant est requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Email ───────────────────────────────────────────────────
                AppTextField(
                  label: 'Email',
                  hint: 'votre@email.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email requis';
                    final trimmed = v.trim();
                    if (!trimmed.contains('@') || !trimmed.contains('.')) {
                      return 'Format d\'email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password ────────────────────────────────────────────────
                AppTextField(
                  label: 'Mot de passe',
                  controller: _passCtrl,
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
                    if (v != _passCtrl.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Security question ───────────────────────────────────────
                const Text('Question de sécurité',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text(
                  'Utilisée si vous oubliez votre mot de passe.',
                  style: TextStyle(fontSize: 12, color: AppColors.grey500),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedQuestion,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.help_outline,
                        color: AppColors.grey500, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.grey300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.grey300),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  isExpanded: true,
                  items: _kSecurityQuestions
                      .map((q) => DropdownMenuItem(
                            value: q,
                            child: Text(q,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedQuestion = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Votre réponse',
                  hint: 'Votre réponse (insensible à la casse)',
                  controller: _answerCtrl,
                  prefixIcon: Icons.vpn_key_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'La réponse est requise';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Terms ───────────────────────────────────────────────────
                Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      activeColor: AppColors.primary,
                      onChanged: (v) =>
                          setState(() => _acceptTerms = v ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _acceptTerms = !_acceptTerms),
                        child: const Text.rich(
                          TextSpan(
                            text: "J'accepte les ",
                            children: [
                              TextSpan(
                                text: "conditions d'utilisation",
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                AppButton(
                  label: 'S\'inscrire',
                  onPressed: _submit,
                  isLoading: isLoading,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Déjà un compte ?'),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── _TypeTab ──────────────────────────────────────────────────────────────────

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.grey500),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.grey500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
