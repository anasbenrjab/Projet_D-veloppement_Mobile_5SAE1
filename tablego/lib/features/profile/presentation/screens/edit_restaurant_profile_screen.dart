import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../providers/profile_provider.dart';

class EditRestaurantProfileScreen extends ConsumerStatefulWidget {
  const EditRestaurantProfileScreen({super.key});

  @override
  ConsumerState<EditRestaurantProfileScreen> createState() =>
      _EditRestaurantProfileScreenState();
}

class _EditRestaurantProfileScreenState
    extends ConsumerState<EditRestaurantProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cuisineCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  bool _initialized = false;

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

  void _initFromProfile(Map<String, dynamic> p) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = p['name'] ?? '';
    _addressCtrl.text = p['address'] ?? '';
    _cuisineCtrl.text = p['cuisine_type'] ?? '';
    _descCtrl.text = p['description'] ?? '';
    _latCtrl.text = p['latitude']?.toString() ?? '';
    _lngCtrl.text = p['longitude']?.toString() ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final success =
        await ref.read(profileProvider.notifier).updateRestaurantProfile(
              name: _nameCtrl.text.trim(),
              address: _addressCtrl.text.trim(),
              cuisineType: _cuisineCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              latitude: double.tryParse(_latCtrl.text.trim()),
              longitude: double.tryParse(_lngCtrl.text.trim()),
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
      appBar: AppBar(title: const Text('Modifier le restaurant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Nom du restaurant',
                controller: _nameCtrl,
                prefixIcon: Icons.store_outlined,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nom requis' : null,
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
