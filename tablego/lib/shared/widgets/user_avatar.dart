import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/avatar_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/photo_ref.dart';

/// A user's round avatar.
///
/// 1. The profile photo when [photoPath] resolves (file path or `data:` URI).
/// 2. Otherwise a DiceBear initials avatar fetched by [AvatarService].
/// 3. While it loads, or when offline / timed out, local initials.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.photoPath,
    required this.name,
    this.radius = 22,
  });

  final String? photoPath;

  /// Full name, or email when no name is set; used for initials and seed.
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = photoImageProvider(photoPath);
    if (photo != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        backgroundImage: photo,
        // A photo that fails to load leaves the tinted background.
        onBackgroundImageError: (_, _) {},
      );
    }

    final bytes = ref.watch(dicebearAvatarProvider(name)).valueOrNull;
    if (bytes != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary,
        backgroundImage: MemoryImage(bytes),
        // Undecodable bytes leave the plain primary circle, never an error.
        onBackgroundImageError: (_, _) {},
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(
        AvatarService.initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
