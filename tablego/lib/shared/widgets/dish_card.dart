import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class DishCard extends StatelessWidget {
  const DishCard({
    super.key,
    required this.name,
    required this.price,
    required this.restaurantName,
    this.description,
    this.photoPath,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.onTap,
  });

  final String name;
  final double price;
  final String restaurantName;
  final String? description;

  /// Absolute path to a local file.  Null or missing file → placeholder.
  final String? photoPath;

  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: SizedBox(
                width: 90,
                height: 90,
                child: _buildImage(),
              ),
            ),
            // ── Info ──────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(restaurantName,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.grey500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text('${price.toStringAsFixed(2)} €',
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            // ── Heart ─────────────────────────────────────────────────────
            if (onFavoriteTap != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: onFavoriteTap,
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? AppColors.primary
                        : AppColors.grey500,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (photoPath != null) {
      final file = File(photoPath!);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: AppColors.grey100,
        child: const Center(
          child: Icon(Icons.fastfood,
              color: AppColors.grey300, size: 32),
        ),
      );
}
