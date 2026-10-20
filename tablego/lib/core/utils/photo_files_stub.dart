import 'package:flutter/widgets.dart';

/// Web has no local file system, so a path can never be resolved.
ImageProvider? fileImageProvider(String path) => null;

/// Never called on web: [ProfileRepository] stores the image bytes in the
/// `profile_photos` table instead of copying a file.
Future<String> copyPhotoToDocuments(String sourcePath) =>
    throw UnsupportedError('No file system on this platform');

/// Never called on web.
Future<void> deleteStoredPhoto(String path) async {}
