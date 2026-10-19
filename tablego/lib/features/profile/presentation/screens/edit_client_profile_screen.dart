import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../providers/profile_provider.dart';
import '../../data/repositories/profile_repository.dart';

const _kDietaryOptions = [
  'halal', 'vegetarian', 'vegan', 'pescatarian', 'gluten-free', 'kosher'
];
const _kAllergyOptions = [
  'peanuts', 'gluten', 'dairy', 'eggs', 'soy', 'shellfish', 'tree nuts', 'fish'
];

class EditClientProfileScreen extends ConsumerStatefulWidget {
  const EditClientProfileScreen({super.key});

  @override
  ConsumerState<EditClientProfileScreen> createState() =>
      _EditClientProfileScreenState();
}

class _EditClientProfileScreenState
    extends ConsumerState<EditClientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  Set<String> _selectedDietary = {};
  Set<String> _selectedAllergies = {};
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(Map<String, dynamic> profile) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = profile['full_name'] ?? '';
    _phoneCtrl.text = profile['phone'] ?? '';
    final prefs = parseStringList(profile['dietary_preferences']);
    final allergies = parseStringList(profile['allergies']);
    setState(() {
      _selectedDietary = Set.from(prefs);
      _selectedAllergies = Set.from(allergies);
    });
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    try {
      await ref.read(profileRepositoryProvider).uploadPhoto(image.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo mise à jour')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final success =
        await ref.read(profileProvider.notifier).updateClientProfile(
              fullName: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              dietaryPreferences: _selectedDietary.toList(),
              allergies: _selectedAllergies.toList(),
            );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    if (state.data != null) _initFromProfile(state.data!);

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo
              Center(
                child: GestureDetector(
                  onTap: _pickAndUploadPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.grey100,
                        child: const Icon(Icons.person,
                            size: 48, color: AppColors.grey500),
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
                    v == null || v.isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Téléphone',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: 24),
              // Dietary preferences
              const Text('Préférences alimentaires',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kDietaryOptions
                    .map((pref) => FilterChip(
                          label: Text(pref),
                          selected: _selectedDietary.contains(pref),
                          selectedColor: AppColors.eco.withOpacity(0.2),
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
              // Allergies
              const Text('Allergies',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kAllergyOptions
                    .map((a) => FilterChip(
                          label: Text(a),
                          selected: _selectedAllergies.contains(a),
                          selectedColor: AppColors.error.withOpacity(0.15),
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
