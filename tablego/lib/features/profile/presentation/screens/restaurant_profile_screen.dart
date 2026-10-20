import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class RestaurantProfileScreen extends ConsumerStatefulWidget {
  const RestaurantProfileScreen({super.key});

  @override
  ConsumerState<RestaurantProfileScreen> createState() =>
      _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState
    extends ConsumerState<RestaurantProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  void _load() {
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      ref.read(profileProvider.notifier).loadRestaurantProfile(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);

    if (state.isLoading && state.data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = state.data is RestaurantData
        ? (state.data! as RestaurantData).profile
        : null;

    final name        = profile?.name ?? 'Mon Restaurant';
    final address     = profile?.address ?? '';
    final cuisineType = profile?.cuisineType ?? '';
    final description = profile?.description ?? '';
    final photoPaths  = profile?.photoPaths ?? const [];
    final hours       = profile?.openingHours ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon restaurant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.of(context)
                  .pushNamed('/edit-restaurant-profile');
              _load();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header image ─────────────────────────────────────────────────
            SizedBox(
              height: 200,
              width: double.infinity,
              child: photoPaths.isNotEmpty
                  ? _localOrPlaceholder(photoPaths.first)
                  : _placeholder(),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Name + cuisine ────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (cuisineType.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(cuisineType,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.grey500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(address,
                              style: const TextStyle(
                                  color: AppColors.grey500, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(description,
                        style:
                            const TextStyle(fontSize: 14, height: 1.5)),
                  ],

                  // ── Opening hours ─────────────────────────────────────────
                  if (hours.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Horaires d\'ouverture',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    ...hours.entries.map((e) {
                      final v = e.value;
                      final open  = (v is Map ? v['open']  : '') ?? '';
                      final close = (v is Map ? v['close'] : '') ?? '';
                      return _HourRow(
                          day: e.key,
                          open: open.toString(),
                          close: close.toString());
                    }),
                  ],

                  // ── Photos grid ───────────────────────────────────────────
                  if (photoPaths.length > 1) ...[
                    const SizedBox(height: 20),
                    const Text('Photos',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8),
                      itemCount: photoPaths.length,
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _localOrPlaceholder(photoPaths[i]),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  ListTile(
                    leading:
                        const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Se déconnecter'),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.of(context)
                            .pushReplacementNamed('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a local file image if the path exists on disk, otherwise the
  /// placeholder — so the screen never crashes on a missing file.
  Widget _localOrPlaceholder(String path) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover, width: double.infinity);
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: AppColors.grey100,
        child: const Center(
            child:
                Icon(Icons.store, size: 72, color: AppColors.grey300)),
      );
}

class _HourRow extends StatelessWidget {
  const _HourRow(
      {required this.day, required this.open, required this.close});
  final String day, open, close;

  static const _days = {
    'mon': 'Lundi',
    'tue': 'Mardi',
    'wed': 'Mercredi',
    'thu': 'Jeudi',
    'fri': 'Vendredi',
    'sat': 'Samedi',
    'sun': 'Dimanche',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(_days[day] ?? day,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Text('$open – $close',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.grey500)),
        ],
      ),
    );
  }
}
