/// Platform-specific photo file helpers.
///
/// On mobile (`dart:io`) a picked photo is copied into the app documents
/// directory and referenced by its file path.  On web there is no file
/// system, so the stubs resolve to null / no-op and the repository keeps the
/// image bytes in the `profile_photos` table instead
/// (see `ProfileRepository.saveProfilePhoto`).
library;

export 'photo_files_stub.dart' if (dart.library.io) 'photo_files_io.dart';
