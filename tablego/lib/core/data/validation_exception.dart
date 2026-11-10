/// Invalid data refused by a repository (the last line of defence behind
/// the forms).  [toString] is the French message, so screens that display
/// an error as `'$e'` show a readable sentence.
class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
