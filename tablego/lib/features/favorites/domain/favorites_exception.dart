/// Typed exception thrown by [FavoritesRepository].
class FavoritesException implements Exception {
  const FavoritesException(this.message);
  final String message;

  @override
  String toString() => 'FavoritesException: $message';
}
