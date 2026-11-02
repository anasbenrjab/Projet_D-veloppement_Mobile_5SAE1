import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'photo_files.dart';

/// A photo reference is the string stored for a photo:
///
/// * **Bundled asset** — `assets/images/...`, e.g. the dev-seed photos.
///   Resolved with [AssetImage] on every platform.
/// * **Mobile upload** — an absolute file path
///   (`.../profile_photos/<uuid>.jpg`), resolved through `dart:io`.
/// * **Web upload** — a `data:<mime>;base64,<bytes>` URI, because the browser
///   has no file system and the bytes live in the `profile_photos` table.
///
/// [photoImageProvider] turns any of these into an [ImageProvider].  This file
/// never touches `dart:io`, so it compiles on web as well.
const String _dataUriPrefix = 'data:';
const String _assetPrefix = 'assets/';

/// Fallback image for a restaurant without a usable photo.
const String kRestaurantPlaceholderAsset =
    'assets/images/placeholders/restaurant.jpg';

/// Fallback image for a dish without a usable photo.
const String kDishPlaceholderAsset = 'assets/images/placeholders/dish.jpg';

/// True when [ref] is a base64 data URI rather than a file path.
bool isDataUriPhoto(String ref) => ref.startsWith(_dataUriPrefix);

/// True when [ref] points at an image bundled with the app.  Such references
/// are shared, read-only files: never delete them.
bool isAssetPhoto(String ref) => ref.startsWith(_assetPrefix);

/// Resolves [ref] to an [ImageProvider], or null when it is null/empty, a
/// missing file, or a malformed data URI — callers then show a placeholder.
ImageProvider? photoImageProvider(String? ref) {
  if (ref == null || ref.isEmpty) return null;
  if (isAssetPhoto(ref)) return AssetImage(ref);
  if (!isDataUriPhoto(ref)) return fileImageProvider(ref);

  final comma = ref.indexOf(',');
  if (comma == -1) return null;
  try {
    return MemoryImage(base64Decode(ref.substring(comma + 1)));
  } catch (_) {
    return null;
  }
}

/// Builds the web photo reference stored in the database.
String encodePhotoDataUri(String mimeType, List<int> bytes) =>
    'data:$mimeType;base64,${base64Encode(bytes)}';
