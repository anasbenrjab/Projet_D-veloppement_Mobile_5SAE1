import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// A WGS84 coordinate.
@immutable
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// Turns a postal address into coordinates with the OpenStreetMap Nominatim
/// web service (https://nominatim.org, `/search` endpoint).
///
/// Every failure — no network, timeout, non-200 status, empty result,
/// malformed JSON — returns `null`; callers treat that as "location unknown".
///
/// Nominatim usage policy: identify the app (User-Agent), at most one request
/// per second.  Requests happen only when a restaurant saves a new address.
/// Browsers do not let a page set User-Agent, so on web Nominatim identifies
/// the app by its Referer instead.
class GeocodingService {
  GeocodingService({
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Upper bound on one request.
  final Duration timeout;

  static const userAgent = 'TableGo-student-project';

  /// The request URL for [address] (exposed for tests).
  @visibleForTesting
  static Uri urlFor(String address) =>
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': address,
        'format': 'json',
        'limit': '1',
      });

  /// Coordinates of the best match for [address], or `null`.
  Future<GeoPoint?> geocode(String address) async {
    final query = address.trim();
    if (query.isEmpty) return null;
    try {
      final response = await _client.get(
        urlFor(query),
        headers: const {'User-Agent': userAgent},
      ).timeout(timeout);
      if (response.statusCode != 200) {
        _log('HTTP ${response.statusCode}');
        return null;
      }
      final results = jsonDecode(utf8.decode(response.bodyBytes));
      if (results is! List || results.isEmpty) {
        _log('no result for "$query"');
        return null;
      }
      final first = results.first as Map<String, dynamic>;
      final lat = double.tryParse('${first['lat']}');
      final lon = double.tryParse('${first['lon']}');
      if (lat == null || lon == null) {
        _log('result without coordinates');
        return null;
      }
      return GeoPoint(lat, lon);
    } on TimeoutException {
      _log('timed out after $timeout');
      return null;
    } catch (e) {
      // Offline, DNS/TLS failure, malformed JSON…
      _log('unavailable: $e');
      return null;
    }
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[Geocoding] Nominatim $message');
  }
}

final geocodingServiceProvider =
    Provider<GeocodingService>((_) => GeocodingService());
