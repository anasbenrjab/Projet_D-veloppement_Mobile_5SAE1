import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'photo_files.dart';

/// A photo reference is the string stored for a profile photo:
///
/// * **Mobile** — an absolute file path
///   (`.../profile_photos/<uuid>.jpg`), resolved through `dart:io`.
/// * **Web** — a `data:<mime>;base64,<bytes>` URI, because the browser has no
///   file system and the bytes live in the `profile_photos` table.
///
/// [photoImageProvider] turns either form into an [ImageProvider].  This file
/// never touches `dart:io`, so it compiles on web as well.
const String _dataUriPrefix = 'data:';

/// True when [ref] is a base64 data URI rather than a file path.
bool isDataUriPhoto(String ref) => ref.startsWith(_dataUriPrefix);

/// Resolves [ref] to an [ImageProvider], or null when it is null/empty, a
/// missing file, or a malformed data URI — callers then show a placeholder.
ImageProvider? photoImageProvider(String? ref) {
  if (ref == null || ref.isEmpty) return null;
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
