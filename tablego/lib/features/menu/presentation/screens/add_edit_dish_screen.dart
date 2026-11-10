import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/models/dish_model.dart';
import '../../providers/dish_provider.dart';
import '../../services/dish_ai_service.dart';
import '../../../../shared/widgets/dish_image.dart';
import '../widgets/meal_photo_picker.dart';

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.expand = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.textDark;
    return Material(
      color: primary ? AppColors.primary : Colors.white,
      borderRadius: expand ? null : BorderRadius.circular(12),
      shape: expand
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: primary
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.border))
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 12, vertical: expand ? 13 : 8),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class AddEditDishScreen extends ConsumerStatefulWidget {
  const AddEditDishScreen({super.key, this.dish});
  final DishModel? dish;

  @override
  ConsumerState<AddEditDishScreen> createState() =>
      _AddEditDishScreenState();
}

class _AddEditDishScreenState extends ConsumerState<AddEditDishScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _allergensCtrl;
  late String _selectedCategory;
  late bool _isAvailable;
  String? _imageUrl;
  bool _isSaving = false;
  bool _isLoadingAi = false;

  bool get _isEditing => widget.dish != null;

  @override
  void initState() {
    super.initState();
    final d = widget.dish;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _descCtrl = TextEditingController(text: d?.description ?? '');
    _priceCtrl = TextEditingController(
        text: d != null ? d.price.toStringAsFixed(3) : '');
    _allergensCtrl = TextEditingController(text: d?.allergens ?? '');
    _selectedCategory = d?.category ?? DishModel.categories.first;
    _isAvailable = d?.isAvailable ?? true;
    _imageUrl = d?.imagePath;
  }

  /// Photo search on TheMealDB (external API).
  Future<void> _pickPhoto() async {
    final name = _nameCtrl.text.trim();
    final url = await showMealPhotoPicker(context, name);
    if (url != null && mounted) setState(() => _imageUrl = url);
  }

  /// Photo imported from the computer (web/desktop) or gallery (phone).
  Future<void> _importPhoto() async {
    try {
      final dataUri = await pickLocalDishPhoto();
      if (dataUri != null && mounted) setState(() => _imageUrl = dataUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'.replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _allergensCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAiSuggestion() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Saisissez d\'abord le nom du plat.')),
      );
      return;
    }
    setState(() => _isLoadingAi = true);
    try {
      final suggestion =
          await DishAiService.instance.suggestFromName(name);
      setState(() {
        _descCtrl.text = suggestion.description;
        _allergensCtrl.text = suggestion.allergensLabel;
        if (DishModel.categories.contains(suggestion.category)) {
          _selectedCategory = suggestion.category;
        }
        _isLoadingAi = false;
      });
      if (mounted) {
        final source = suggestion.isAiGenerated ? '✨ Gemini AI' : '✨ Suggestion locale';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$source appliquée !'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAi = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur IA: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final priceText = _priceCtrl.text.trim();
    final price = double.tryParse(priceText);
    if (price == null || price < 0) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prix invalide')),
      );
      return;
    }

    final dish = DishModel(
      id: widget.dish?.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: price,
      category: _selectedCategory,
      imagePath: _imageUrl,
      isAvailable: _isAvailable,
      allergens: _allergensCtrl.text.trim().isEmpty
          ? 'Aucun'
          : _allergensCtrl.text.trim(),
      createdAt: widget.dish?.createdAt ?? DateTime.now(),
    );

    final notifier = ref.read(dishProvider.notifier);
    final bool success;
    if (_isEditing) {
      success = await notifier.updateDish(dish);
    } else {
      success = await notifier.addDish(dish);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(dishProvider).error ?? 'Erreur inconnue';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le plat' : 'Nouveau plat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Photo (TheMealDB external API) ──────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DishImage(
                        url: _imageUrl,
                        name: _nameCtrl.text.isEmpty ? '+' : _nameCtrl.text,
                        initialSize: 48),
                    if (_imageUrl != null)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: _PhotoButton(
                          icon: Icons.delete_outline,
                          label: 'Retirer',
                          onTap: () => setState(() => _imageUrl = null),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PhotoButton(
                    icon: Icons.upload_file,
                    label: 'Importer',
                    onTap: _importPhoto,
                    primary: true,
                    expand: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PhotoButton(
                    icon: Icons.image_search,
                    label: 'TheMealDB',
                    onTap: _pickPhoto,
                    expand: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Name row with AI button ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Nom du plat *',
                    hint: 'Ex: Couscous Royal',
                    controller: _nameCtrl,
                    prefixIcon: Icons.restaurant,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Champ requis'
                            : null,
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Générer avec l\'IA',
                  child: InkWell(
                    onTap: _isLoadingAi ? null : _loadAiSuggestion,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.primary, width: 1.5),
                      ),
                      child: _isLoadingAi
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary))
                          : const Icon(Icons.auto_awesome,
                              color: AppColors.primary, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Description ─────────────────────────────────────────
            AppTextField(
              label: 'Description',
              hint: 'Décrivez le plat...',
              controller: _descCtrl,
              maxLines: 3,
              prefixIcon: Icons.notes,
            ),
            const SizedBox(height: 16),

            // ── Price ───────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prix (DT) *',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '0.000',
                    prefixText: 'DT  ',
                    prefixStyle: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Champ requis';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed < 0) return 'Prix invalide';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Category ────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Catégorie *',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DishModel.categories.map((cat) {
                    final selected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      selectedColor: AppColors.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.grey700,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Allergens ───────────────────────────────────────────
            AppTextField(
              label: 'Allergènes',
              hint: 'Ex: Gluten, Lait, Œuf',
              controller: _allergensCtrl,
              prefixIcon: Icons.warning_amber_outlined,
            ),
            const SizedBox(height: 16),

            // ── Availability ────────────────────────────────────────
            Card(
              child: SwitchListTile(
                title: const Text('Plat disponible'),
                subtitle: const Text(
                    'Les clients peuvent commander ce plat',
                    style: TextStyle(fontSize: 12)),
                value: _isAvailable,
                activeColor: AppColors.eco,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
            ),
            const SizedBox(height: 28),

            AppButton(
              label: _isEditing ? 'Enregistrer' : 'Ajouter le plat',
              onPressed: _save,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}
