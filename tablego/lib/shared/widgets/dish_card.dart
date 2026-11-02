import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'photo_image.dart';
import 'recommendation_reason.dart';

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
    this.reason,
  });

  final String name;
  final double price;
  final String restaurantName;
  final String? description;

  /// Bundled asset path, absolute file path (mobile) or data URI (web).  Null
  /// or unresolvable → dish placeholder image.
  final String? photoPath;

  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onTap;

  /// Optional "why" line (recommendations), shown under the price.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
        ),
        // At least 90 px tall; taller when a reason is shown, with the
        // thumbnail stretched to the full height.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 90),
          child: IntrinsicHeight(child: _buildRow()),
        ),
      ),
    );
  }

  Widget _buildRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Thumbnail ───────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          child: SizedBox(width: 90, child: _buildImage()),
        ),
        // ── Info ────────────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                if (reason != null && reason!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  RecommendationReason(reason!),
                ],
              ],
            ),
          ),
        ),
        // ── Heart ───────────────────────────────────────────────────────────
        if (onFavoriteTap != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: onFavoriteTap,
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? AppColors.primary : AppColors.grey500,
                size: 22,
              ),
            ),
          ),
      ],
    );
  }

  /// Shows the resolved photo if there is one, otherwise the dish placeholder.
  Widget _buildImage() => PhotoImage.dish(photoPath);
}
