import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tablego/core/services/avatar_service.dart';
import 'package:tablego/shared/widgets/user_avatar.dart';

/// A valid 1×1 PNG.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

http.Response _pngResponse() =>
    http.Response.bytes(_png, 200, headers: {'content-type': 'image/png'});

void main() {
  group('AvatarService.fetchInitialsAvatar', () {
    test('returns the PNG bytes on success and calls DiceBear', () async {
      Uri? called;
      final service = AvatarService(
        client: MockClient((req) async {
          called = req.url;
          return _pngResponse();
        }),
      );

      expect(await service.fetchInitialsAvatar('Alice Martin'), _png);
      expect(called!.host, 'api.dicebear.com');
      expect(called!.path, '/9.x/initials/png');
      expect(called!.queryParameters['seed'], 'alice martin');
    });

    test('caches per seed: one request for repeated calls', () async {
      var calls = 0;
      final service = AvatarService(
        client: MockClient((_) async {
          calls++;
          return _pngResponse();
        }),
      );

      await service.fetchInitialsAvatar('Alice');
      await service.fetchInitialsAvatar('alice ');
      expect(calls, 1);
    });

    test('null on non-200 status', () async {
      final service =
          AvatarService(client: MockClient((_) async => http.Response('', 500)));
      expect(await service.fetchInitialsAvatar('Alice'), isNull);
    });

    test('null when the body is not an image', () async {
      final service = AvatarService(
        client: MockClient((_) async => http.Response('<html>', 200,
            headers: {'content-type': 'text/html'})),
      );
      expect(await service.fetchInitialsAvatar('Alice'), isNull);
    });

    test('null on timeout', () async {
      final service = AvatarService(
        timeout: const Duration(milliseconds: 50),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return _pngResponse();
        }),
      );
      expect(await service.fetchInitialsAvatar('Alice'), isNull);
    });

    test('null when offline', () async {
      final service = AvatarService(
        client: MockClient(
            (_) async => throw const SocketException('no network')),
      );
      expect(await service.fetchInitialsAvatar('Alice'), isNull);
    });

    test('empty seed: no request, null', () async {
      final service = AvatarService(
        client: MockClient((_) async => fail('must not be called')),
      );
      expect(await service.fetchInitialsAvatar('  '), isNull);
    });
  });

  group('AvatarService.initials', () {
    test('first letters of the first two words', () {
      expect(AvatarService.initials('alice martin dupont'), 'AM');
      expect(AvatarService.initials('Élodie'), 'É');
    });

    test('email: local part split on . _ -', () {
      expect(AvatarService.initials('jean.dupont@test.com'), 'JD');
      expect(AvatarService.initials('client@test.com'), 'C');
    });

    test('empty → ?', () => expect(AvatarService.initials(' '), '?'));
  });

  group('UserAvatar', () {
    Future<void> pump(WidgetTester tester, AvatarService service) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [avatarServiceProvider.overrideWithValue(service)],
            child: const MaterialApp(
              home: Scaffold(
                body: UserAvatar(photoPath: null, name: 'Alice Martin'),
              ),
            ),
          ),
        );

    testWidgets('offline: shows local initials', (tester) async {
      await pump(
        tester,
        AvatarService(
          client: MockClient((_) async => throw const SocketException('x')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AM'), findsOneWidget);
    });

    testWidgets('online: shows the DiceBear image', (tester) async {
      await pump(
        tester,
        AvatarService(client: MockClient((_) async => _pngResponse())),
      );
      // Initials while loading…
      expect(find.text('AM'), findsOneWidget);
      await tester.pumpAndSettle();
      // …then the fetched image.
      expect(find.text('AM'), findsNothing);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<MemoryImage>());
    });
  });
}
