/// Typed exception thrown by [ProfileRepository].
///
/// Mirrors [AuthException] in the auth module — callers pattern-match on the
/// type and display [message] directly in the UI.
class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => 'ProfileException: $message';
}
