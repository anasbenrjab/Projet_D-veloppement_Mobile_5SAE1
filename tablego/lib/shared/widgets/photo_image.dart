import 'package:flutter/material.dart';

import '../../core/utils/photo_ref.dart';

/// Shows the photo behind a stored reference (bundled asset, mobile file
/// path or web data URI), falling back to [placeholderAsset] when the
/// reference is empty or cannot be loaded — so a missing file or corrupt
/// upload never shows a broken image.
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    required this.photoRef,
    required this.placeholderAsset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  /// Restaurant photo with the restaurant placeholder as fallback.
  const PhotoImage.restaurant(
    this.photoRef, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : placeholderAsset = kRestaurantPlaceholderAsset;

  /// Dish photo with the dish placeholder as fallback.
  const PhotoImage.dish(
    this.photoRef, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : placeholderAsset = kDishPlaceholderAsset;

  final String? photoRef;
  final String placeholderAsset;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = Image.asset(
      placeholderAsset,
      width: width,
      height: height,
      fit: fit,
    );
    final image = photoImageProvider(photoRef);
    if (image == null) return placeholder;
    return Image(
      image: image,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}
