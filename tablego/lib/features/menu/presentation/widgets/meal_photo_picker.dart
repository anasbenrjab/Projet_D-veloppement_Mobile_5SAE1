import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/dish_image.dart' show pickLocalDishPhoto;
import '../../services/meal_db_service.dart';

/// Bottom sheet: searches TheMealDB for [dishName] and returns the
/// chosen photo URL (or null if dismissed).
Future<String?> showMealPhotoPicker(BuildContext context, String dishName) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _MealPhotoSheet(initialQuery: dishName),
  );
}

class _MealPhotoSheet extends ConsumerStatefulWidget {
  const _MealPhotoSheet({required this.initialQuery});
  final String initialQuery;

  @override
  ConsumerState<_MealPhotoSheet> createState() => _MealPhotoSheetState();
}

class _MealPhotoSheetState extends ConsumerState<_MealPhotoSheet> {
  late final _ctrl = TextEditingController(text: widget.initialQuery);
  Future<List<MealDbRecipe>>? _future;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _run() => setState(() {
        _future = ref.read(mealDbServiceProvider).searchForDish(_ctrl.text);
      });

  /// Fallback: pick a photo from the computer instead.
  Future<void> _import() async {
    try {
      final dataUri = await pickLocalDishPhoto();
      if (dataUri != null && mounted) Navigator.of(context).pop(dataUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Choisir une photo',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            Row(
              children: [
                const Expanded(
                  child: Text('Photos fournies par TheMealDB (API externe)',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                TextButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.upload_file,
                      size: 18, color: AppColors.primary),
                  label: const Text('Importer',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _run(),
              decoration: InputDecoration(
                hintText: 'Ex : tagine, couscous, brik...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward,
                      color: AppColors.primary),
                  onPressed: _run,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<MealDbRecipe>>(
                future: _future,
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off,
                                size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 10),
                            const Text('Impossible de joindre TheMealDB',
                                style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${snap.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _run,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Réessayer'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _import,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Importer une photo'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final meals = snap.data ?? [];
                  if (meals.isEmpty) {
                    return const Center(
                      child: Text(
                          'Aucune photo trouvée.\nEssayez un mot en anglais (ex : lamb, salad).',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted)),
                    );
                  }
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: meals.length,
                    itemBuilder: (_, i) {
                      final m = meals[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(m.thumbnail),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Image.network(m.preview,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          Container(color: AppColors.peach)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12)),
                                    Text(m.area,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
