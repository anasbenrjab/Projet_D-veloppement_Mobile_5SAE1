import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tablego/core/services/geocoding_service.dart';

/// Shape of a real Nominatim `/search?format=json` answer (trimmed).
const _rivoliJson = '[{"place_id":98600583,"lat":"48.8556009",'
    '"lon":"2.3599124","display_name":"12, Rue de Rivoli, Paris"}]';

http.Response _json(String body, [int status = 200]) => http.Response(
      body,
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('success: parses the first result and identifies the app', () async {
    late http.Request sent;
    final service = GeocodingService(
      client: MockClient((req) async {
        sent = req;
        return _json(_rivoliJson);
      }),
    );

    final point = await service.geocode(' 12 Rue de Rivoli, Paris ');

    expect(point, const GeoPoint(48.8556009, 2.3599124));
    expect(sent.url.host, 'nominatim.openstreetmap.org');
    expect(sent.url.path, '/search');
    expect(sent.url.queryParameters, {
      'q': '12 Rue de Rivoli, Paris',
      'format': 'json',
      'limit': '1',
    });
    expect(sent.headers['User-Agent'], 'TableGo-student-project');
  });

  test('empty result → null', () async {
    final service = GeocodingService(client: MockClient((_) async => _json('[]')));
    expect(await service.geocode('Nulle part 99999'), isNull);
  });

  test('timeout → null', () async {
    final service = GeocodingService(
      timeout: const Duration(milliseconds: 50),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return _json(_rivoliJson);
      }),
    );
    expect(await service.geocode('12 Rue de Rivoli'), isNull);
  });

  test('offline → null', () async {
    final service = GeocodingService(
      client: MockClient(
          (_) async => throw const SocketException('Failed host lookup')),
    );
    expect(await service.geocode('12 Rue de Rivoli'), isNull);
  });

  test('HTTP 500 → null', () async {
    final service =
        GeocodingService(client: MockClient((_) async => _json('oops', 500)));
    expect(await service.geocode('12 Rue de Rivoli'), isNull);
  });

  test('malformed JSON or missing coordinates → null', () async {
    final notJson =
        GeocodingService(client: MockClient((_) async => _json('<html>')));
    final noCoords = GeocodingService(
        client: MockClient((_) async => _json('[{"display_name":"x"}]')));
    expect(await notJson.geocode('a'), isNull);
    expect(await noCoords.geocode('a'), isNull);
  });

  test('blank address: no request', () async {
    final service = GeocodingService(
      client: MockClient((_) async => fail('must not be called')),
    );
    expect(await service.geocode('   '), isNull);
  });
}
