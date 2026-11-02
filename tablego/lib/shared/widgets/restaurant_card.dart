import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'photo_image.dart';
import 'recommendation_reason.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.name,
    required this.cuisineType,
    required this.address,
    this.photoPath,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.onTap,
    this.showAiBadge = false,
    this.reason,
  });

  final String name;
  final String cuisineType;
  final String address;

  /// Bundled asset path, absolute file path (mobile) or data URI (web).  Null
  /// or unresolvable → restaurant placeholder image.
  final String? photoPath;

  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onTap;
  final bool showAiBadge;

  /// Optional "why" line (recommendations), shown under the address.
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ────────────────────────────────────────────────────────
            Stack(
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: _buildImage(),
                ),
                if (showAiBadge)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome,
                              color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text('IA',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                if (onFavoriteTap != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavoriteTap,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isFavorite
                              ? AppColors.primary
                              : AppColors.grey500,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // ── Info ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(cuisineType,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(address,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grey500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (reason != null && reason!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    RecommendationReason(reason!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the resolved photo if there is one, otherwise the restaurant
  /// placeholder — never crashes on a missing file or unresolvable reference.
  Widget _buildImage() =>
      PhotoImage.restaurant(photoPath, width: double.infinity);
}
