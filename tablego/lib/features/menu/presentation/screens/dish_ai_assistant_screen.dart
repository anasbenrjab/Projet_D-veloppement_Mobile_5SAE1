import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/models/dish_model.dart';
import '../../services/dish_ai_service.dart';
import 'add_edit_dish_screen.dart';

/// AI assistant screen: enter a dish name → get description, category, allergens.
class DishAiAssistantScreen extends ConsumerStatefulWidget {
  const DishAiAssistantScreen({super.key, this.standalone = true});
  final bool standalone;

  @override
  ConsumerState<DishAiAssistantScreen> createState() =>
      _DishAiAssistantScreenState();
}

class _DishAiAssistantScreenState
    extends ConsumerState<DishAiAssistantScreen> {
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  DishSuggestion? _suggestion;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isLoading = true;
      _suggestion = null;
      _error = null;
    });

    try {
      final suggestion =
          await DishAiService.instance.suggestFromName(name);
      setState(() {
        _suggestion = suggestion;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  void _createDishFromSuggestion() {
    final s = _suggestion;
    if (s == null) return;
    final dish = DishModel(
      name: _nameCtrl.text.trim(),
      description: s.description,
      price: 0.0,
      category: s.category,
      allergens: s.allergensLabel,
      createdAt: DateTime.now(),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => AddEditDishScreen(dish: dish)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.all(20),
      children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.lightbulb_outline, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Comment ça marche ?',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Entrez le nom de votre plat et notre assistant génère automatiquement '
                  'une description, une catégorie et les allergènes probables.',
                  style:
                      TextStyle(color: AppColors.grey700, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Input + button
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _analyze(),
            decoration: InputDecoration(
              labelText: 'Nom du plat',
              hintText: 'Ex: Tajine Poulet, Salade Niçoise...',
              prefixIcon:
                  const Icon(Icons.restaurant, color: AppColors.grey500),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: AppColors.grey500),
                onPressed: () {
                  _nameCtrl.clear();
                  setState(() {
                    _suggestion = null;
                    _error = null;
                  });
                },
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),

          AppButton(
            label: '✨  Analyser avec l\'IA',
            onPressed: _isLoading ? null : _analyze,
            isLoading: _isLoading,
          ),

          const SizedBox(height: 24),

          // Results
          if (_error != null)
            _ErrorCard(message: _error!),

          if (_suggestion != null) ...[
            _SuggestionCard(suggestion: _suggestion!),
            const SizedBox(height: 16),
            // Combo suggestions
            _ComboCard(
                category: _suggestion!.category),
            const SizedBox(height: 24),
            AppButton(
              label: 'Créer ce plat →',
              onPressed: _createDishFromSuggestion,
            ),
          ],
        ],
      );

    // When embedded in a tab (standalone: false), return content directly
    if (!widget.standalone) return content;

    // When opened as a standalone route, wrap in Scaffold
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Assistant IA — Plats'),
          ],
        ),
      ),
      body: content,
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});
  final DishSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('Suggestion générée',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (suggestion.isAiGenerated)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done_outlined,
                          size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Gemini AI',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Hors ligne',
                      style: TextStyle(
                          color: AppColors.grey700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
            const Divider(height: 20),
            _Row(
              icon: Icons.category_outlined,
              label: 'Catégorie',
              value: suggestion.category,
            ),
            const SizedBox(height: 12),
            _Row(
              icon: Icons.notes,
              label: 'Description',
              value: suggestion.description,
            ),
            const SizedBox(height: 12),
            _Row(
              icon: Icons.warning_amber_outlined,
              label: 'Allergènes détectés',
              value: suggestion.allergensLabel,
              valueColor: suggestion.allergens.first == 'Aucun'
                  ? AppColors.eco
                  : AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  const _ComboCard({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final combos = DishAiService.instance.suggestCombos(category);
    return Card(
      color: AppColors.grey100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.dining, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text('Combos suggérés',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Les clients qui commandent ce plat commandent souvent aussi :',
              style: TextStyle(
                  fontSize: 12, color: AppColors.grey700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: combos
                  .map((c) => Chip(
                        label: Text(c,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.grey500),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.grey500,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      color: valueColor ?? AppColors.textDark)),
            ],
          ),
        ),
      ],
    );
  }
}
