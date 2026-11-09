import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';

/// OpenStreetMap map centred on a restaurant, with a marker.
///
/// Shows a "Localisation indisponible" placeholder when either coordinate is
/// missing (no address, or Nominatim could not geocode it).
class RestaurantLocationMap extends StatelessWidget {
  const RestaurantLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 200,
    @visibleForTesting this.tileProvider,
  });

  final double? latitude;
  final double? longitude;
  final double height;

  /// Overrides the network tile provider (tests only).
  final TileProvider? tileProvider;

  /// OSM tile usage policy: identify the app.  Matches the Android
  /// applicationId.
  static const userAgentPackageName = 'com.example.tablego';

  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return _placeholder();

    final point = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 16,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl,
              userAgentPackageName: userAgentPackageName,
              tileProvider: tileProvider,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: const Icon(Icons.location_on,
                      color: AppColors.primary, size: 40),
                ),
              ],
            ),
            // Required by the OSM tile usage policy.
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                color: AppColors.grey500, size: 36),
            SizedBox(height: 8),
            Text('Localisation indisponible',
                style: TextStyle(color: AppColors.grey500)),
          ],
        ),
      ),
    );
  }
}
