/// Typed exception thrown by [AuthRepository].
///
/// Using a dedicated exception class instead of [Exception] lets callers
/// pattern-match on the type and display the [message] directly in the UI
/// without parsing a string.
///
/// ```dart
/// try {
///   await _repo.login(email: email, password: password);
/// } on AuthException catch (e) {
///   state = state.copyWith(error: e.message);
/// }
/// ```
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
