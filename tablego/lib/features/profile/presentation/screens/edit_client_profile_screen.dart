import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/models/client_profile_model.dart';
import '../../providers/profile_provider.dart';

const _kDietaryOptions = [
  'halal', 'vegetarian', 'vegan', 'pescatarian', 'gluten-free', 'kosher',
];
const _kAllergyOptions = [
  'peanuts', 'gluten', 'dairy', 'eggs', 'soy', 'shellfish', 'tree nuts', 'fish',
];

class EditClientProfileScreen extends ConsumerStatefulWidget {
  const EditClientProfileScreen({super.key});

  @override
  ConsumerState<EditClientProfileScreen> createState() =>
      _EditClientProfileScreenState();
}

class _EditClientProfileScreenState
    extends ConsumerState<EditClientProfileScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  Set<String> _selectedDietary   = {};
  Set<String> _selectedAllergies = {};
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(ClientProfileModel profile) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text  = profile.fullName ?? '';
    _phoneCtrl.text = profile.phone ?? '';
    setState(() {
      _selectedDietary   = Set.from(profile.dietaryPreferences);
      _selectedAllergies = Set.from(profile.allergies);
    });
  }

  Future<void> _pickPhoto() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;

    await ref.read(profileProvider.notifier).savePhoto(
          userId:     userId,
          userType:   'client',
          sourcePath: image.path,
        );
    if (mounted) {
      final err = ref.read(profileProvider).error;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        ref.read(profileProvider.notifier).clearError();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo mise à jour')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    final success = await ref.read(profileProvider.notifier).updateClientProfile(
          userId:             userId,
          fullName:           _nameCtrl.text.trim(),
          phone:              _phoneCtrl.text.trim(),
          dietaryPreferences: _selectedDietary.toList(),
          allergies:          _selectedAllergies.toList(),
        );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(profileProvider).error ?? 'Erreur lors de la mise à jour';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      ref.read(profileProvider.notifier).clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(profileProvider);
    final profile = state.data is ClientData
        ? (state.data! as ClientData).profile
        : null;

    if (profile != null) _initFromProfile(profile);

    final photoPath = profile?.photoPath;
    ImageProvider? photoImage;
    if (photoPath != null) {
      final f = File(photoPath);
      if (f.existsSync()) photoImage = FileImage(f);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photo picker ──────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.grey100,
                        backgroundImage: photoImage,
                        child: photoImage == null
                            ? const Icon(Icons.person,
                                size: 48, color: AppColors.grey500)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              AppTextField(
                label: 'Nom complet',
                controller: _nameCtrl,
                prefixIcon: Icons.person_outline,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Téléphone',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: 24),

              // ── Dietary preferences ───────────────────────────────────────
              const Text('Préférences alimentaires',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kDietaryOptions
                    .map((pref) => FilterChip(
                          label: Text(pref),
                          selected: _selectedDietary.contains(pref),
                          selectedColor: AppColors.eco.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.eco,
                          side: BorderSide(
                              color: _selectedDietary.contains(pref)
                                  ? AppColors.eco
                                  : AppColors.grey300),
                          onSelected: (v) => setState(() => v
                              ? _selectedDietary.add(pref)
                              : _selectedDietary.remove(pref)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),

              // ── Allergies ─────────────────────────────────────────────────
              const Text('Allergies',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kAllergyOptions
                    .map((a) => FilterChip(
                          label: Text(a),
                          selected: _selectedAllergies.contains(a),
                          selectedColor:
                              AppColors.error.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.error,
                          side: BorderSide(
                              color: _selectedAllergies.contains(a)
                                  ? AppColors.error
                                  : AppColors.grey300),
                          onSelected: (v) => setState(() => v
                              ? _selectedAllergies.add(a)
                              : _selectedAllergies.remove(a)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),

              AppButton(
                label: 'Enregistrer',
                onPressed: _save,
                isLoading: state.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
