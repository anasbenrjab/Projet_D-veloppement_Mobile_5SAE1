import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Fetches generated initials avatars from the DiceBear web service
/// (https://www.dicebear.com, `initials` style, PNG output).
///
/// Used only for users without a profile photo.  Every failure — no network,
/// timeout, non-200 status, unexpected content — returns `null`, and the UI
/// falls back to a local initials [CircleAvatar].  Results (including
/// failures) are cached per seed for the lifetime of the service, so a
/// screen rebuild never triggers a second request.
class AvatarService {
  AvatarService({
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Upper bound on one request; past it the fallback is shown.
  final Duration timeout;

  final Map<String, Future<Uint8List?>> _cache = {};

  static const _host = 'api.dicebear.com';
  static const _path = '/9.x/initials/png';

  /// The request URL for [seed] (exposed for tests).
  @visibleForTesting
  static Uri urlFor(String seed) => Uri.https(_host, _path, {
        'seed': seed,
        'size': '128',
        // AppColors.primary, without '#'.
        'backgroundColor': 'e85d0c',
      });

  /// PNG bytes of the avatar for [seed], or `null` if unavailable.
  Future<Uint8List?> fetchInitialsAvatar(String seed) {
    final key = seed.trim().toLowerCase();
    if (key.isEmpty) return Future.value(null);
    return _cache.putIfAbsent(key, () => _fetch(key));
  }

  Future<Uint8List?> _fetch(String seed) async {
    try {
      final response = await _client.get(urlFor(seed)).timeout(timeout);
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 &&
          type.startsWith('image/') &&
          response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      if (kDebugMode) {
        debugPrint('[Avatar] DiceBear HTTP ${response.statusCode} ($type)');
      }
      return null;
    } on TimeoutException {
      if (kDebugMode) debugPrint('[Avatar] DiceBear timed out after $timeout');
      return null;
    } catch (e) {
      // Offline, DNS failure, TLS error, CORS on web…
      if (kDebugMode) debugPrint('[Avatar] DiceBear unavailable: $e');
      return null;
    }
  }

  /// Up to two uppercase initials for [name]: first letters of the first two
  /// words, or of the part before `@` for an email.  `?` when empty.
  static String initials(String name) {
    var source = name.trim();
    final at = source.indexOf('@');
    if (at >= 0) source = source.substring(0, at);
    final words = source
        .split(RegExp(r'[\s._\-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    // `runes` keeps characters outside the BMP whole.
    final letters = words.take(2).map((w) => String.fromCharCode(w.runes.first));
    return letters.join().toUpperCase();
  }
}

final avatarServiceProvider = Provider<AvatarService>((_) => AvatarService());

/// DiceBear avatar bytes for a seed (a name or an email); `null` = fallback.
final dicebearAvatarProvider =
    FutureProvider.family<Uint8List?, String>((ref, seed) {
  return ref.watch(avatarServiceProvider).fetchInitialsAvatar(seed);
});
