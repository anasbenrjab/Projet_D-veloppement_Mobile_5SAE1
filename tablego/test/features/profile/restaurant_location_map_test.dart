import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/features/profile/presentation/widgets/restaurant_location_map.dart';

/// A valid 1×1 PNG, served for every tile so tests never hit the network.
final Uint8List _tile = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

class _MemoryTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_tile);
}

/// 280 px wide: a 320 dp phone minus the screen padding.
Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 280, child: child))),
    );

void main() {
  testWidgets('no coordinates → placeholder', (tester) async {
    await tester.pumpWidget(_host(
      const RestaurantLocationMap(latitude: null, longitude: 2.35),
    ));

    expect(find.text('Localisation indisponible'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('coordinates → OSM map with a marker', (tester) async {
    await tester.pumpWidget(_host(
      RestaurantLocationMap(
        latitude: 48.8556,
        longitude: 2.3599,
        tileProvider: _MemoryTiles(),
      ),
    ));
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.text('Localisation indisponible'), findsNothing);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

    final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tiles.urlTemplate, contains('tile.openstreetmap.org'));
    // flutter_map turns userAgentPackageName into a User-Agent header on
    // mobile (browsers do not allow setting it).
    if (!kIsWeb) {
      expect(tiles.tileProvider.headers['User-Agent'],
          'flutter_map (com.example.tablego)');
    }
  });
}
