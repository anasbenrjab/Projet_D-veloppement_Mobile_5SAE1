import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Returns an [ImageProvider] for the on-device file at [path], or null when
/// the file is missing so callers can fall back to a placeholder.
ImageProvider? fileImageProvider(String path) {
  final file = File(path);
  return file.existsSync() ? FileImage(file) : null;
}

/// Copies [sourcePath] into `<documents>/profile_photos/` under a UUID
/// filename and returns the absolute destination path.
Future<String> copyPhotoToDocuments(String sourcePath) async {
  final docsDir   = await getApplicationDocumentsDirectory();
  final photosDir = Directory(p.join(docsDir.path, 'profile_photos'));
  if (!photosDir.existsSync()) await photosDir.create(recursive: true);

  final filename = '${const Uuid().v4()}${p.extension(sourcePath)}';
  final destPath = p.join(photosDir.path, filename);

  await File(sourcePath).copy(destPath);
  return destPath;
}

/// Best-effort delete — file-system errors are swallowed on purpose.
Future<void> deleteStoredPhoto(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Best-effort — do not propagate file-deletion errors.
  }
}
