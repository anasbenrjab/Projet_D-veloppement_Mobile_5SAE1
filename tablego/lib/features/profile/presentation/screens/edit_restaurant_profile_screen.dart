import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/models/restaurant_profile_model.dart';
import '../../providers/profile_provider.dart';

class EditRestaurantProfileScreen extends ConsumerStatefulWidget {
  const EditRestaurantProfileScreen({super.key});

  @override
  ConsumerState<EditRestaurantProfileScreen> createState() =>
      _EditRestaurantProfileScreenState();
}

class _EditRestaurantProfileScreenState
    extends ConsumerState<EditRestaurantProfileScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cuisineCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _latCtrl     = TextEditingController();
  final _lngCtrl     = TextEditingController();
  bool _initialized  = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cuisineCtrl.dispose();
    _descCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(RestaurantProfileModel profile) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text    = profile.name;
    _addressCtrl.text = profile.address ?? '';
    _cuisineCtrl.text = profile.cuisineType ?? '';
    _descCtrl.text    = profile.description ?? '';
    _latCtrl.text     = profile.latitude?.toString() ?? '';
    _lngCtrl.text     = profile.longitude?.toString() ?? '';
  }

  Future<void> _addPhoto() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;

    await ref.read(profileProvider.notifier).savePhoto(
          userId:     userId,
          userType:   'restaurant',
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
            const SnackBar(content: Text('Photo ajoutée')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;

    final success =
        await ref.read(profileProvider.notifier).updateRestaurantProfile(
              userId:      userId,
              name:        _nameCtrl.text.trim(),
              address:     _addressCtrl.text.trim(),
              cuisineType: _cuisineCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              latitude:    double.tryParse(_latCtrl.text.trim()),
              longitude:   double.tryParse(_lngCtrl.text.trim()),
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
    final profile = state.data is RestaurantData
        ? (state.data! as RestaurantData).profile
        : null;

    if (profile != null) _initFromProfile(profile);

    final photoPaths = profile?.photoPaths ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le restaurant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photos ────────────────────────────────────────────────────
              if (photoPaths.isNotEmpty) ...[
                const Text('Photos',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photoPaths.length,
                    separatorBuilder: (_, s) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = File(photoPaths[i]);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: f.existsSync()
                            ? Image.file(f,
                                width: 80, height: 80, fit: BoxFit.cover)
                            : Container(
                                width: 80,
                                height: 80,
                                color: AppColors.grey100,
                                child: const Icon(Icons.broken_image,
                                    color: AppColors.grey300)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _addPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Ajouter une photo'),
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'Nom du restaurant',
                controller: _nameCtrl,
                prefixIcon: Icons.store_outlined,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Adresse',
                controller: _addressCtrl,
                prefixIcon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Latitude',
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: 'Longitude',
                      controller: _lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Type de cuisine',
                controller: _cuisineCtrl,
                prefixIcon: Icons.restaurant_outlined,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Description',
                controller: _descCtrl,
                maxLines: 4,
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
