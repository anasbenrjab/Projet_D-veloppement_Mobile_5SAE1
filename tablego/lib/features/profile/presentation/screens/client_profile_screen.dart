import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  ConsumerState<ClientProfileScreen> createState() =>
      _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  void _load() {
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      ref.read(profileProvider.notifier).loadClientProfile(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);

    if (state.isLoading && state.data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Extract typed model — falls back to empty defaults if not yet loaded.
    final profile = state.data is ClientData
        ? (state.data! as ClientData).profile
        : null;

    final name       = profile?.fullName ?? 'Utilisateur';
    final email      = profile?.email ?? '';
    final phone      = profile?.phone ?? '';
    final photoPath  = profile?.photoPath;
    final prefs      = profile?.dietaryPreferences ?? const [];
    final allergies  = profile?.allergies ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.of(context).pushNamed(Routes.editClientProfile);
              _load();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Avatar ──────────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  _Avatar(photoPath: photoPath, radius: 52),
                  const SizedBox(height: 12),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: const TextStyle(
                          color: AppColors.grey500, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Stats row ────────────────────────────────────────────────────
            Row(
              children: const [
                _StatCard(icon: Icons.favorite,             label: 'Favoris',  value: '—'),
                SizedBox(width: 12),
                _StatCard(icon: Icons.location_on_outlined, label: 'Adresses', value: '—'),
                SizedBox(width: 12),
                _StatCard(icon: Icons.emoji_events_outlined, label: 'Badges',  value: '—'),
              ],
            ),
            const SizedBox(height: 24),

            // ── Info card ────────────────────────────────────────────────────
            _InfoSection(
              title: 'Informations',
              children: [
                _InfoRow(
                    icon: Icons.phone_outlined,
                    text: phone.isEmpty ? 'Non renseigné' : phone),
                _InfoRow(icon: Icons.email_outlined, text: email),
              ],
            ),
            const SizedBox(height: 16),

            // ── Dietary preferences ──────────────────────────────────────────
            if (prefs.isNotEmpty) ...[
              const _SectionHeader(title: 'Préférences alimentaires'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prefs
                    .map((p) =>
                        _PreferenceChip(label: p, color: AppColors.eco))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── Allergies ────────────────────────────────────────────────────
            if (allergies.isNotEmpty) ...[
              const _SectionHeader(title: 'Allergies'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allergies
                    .map((a) =>
                        _PreferenceChip(label: a, color: AppColors.error))
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            _MenuList(),
          ],
        ),
      ),
    );
  }
}

// ── _Avatar ───────────────────────────────────────────────────────────────────

/// Shows a local file photo when [photoPath] is set and the file exists.
/// Falls back to the default icon if the path is null or the file is missing,
/// so the screen never crashes when a file has been deleted externally.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoPath, required this.radius});

  final String? photoPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (photoPath != null) {
      final file = File(photoPath!);
      if (file.existsSync()) image = FileImage(file);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      backgroundImage: image,
      child: image == null
          ? Icon(Icons.person, size: radius, color: AppColors.primary)
          : null,
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.grey500)),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.grey500),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
}

class _PreferenceChip extends StatelessWidget {
  const _PreferenceChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _MenuList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      (Icons.favorite_border,  'Mes favoris',           Routes.favorites),
      (Icons.lock_outline,     'Changer le mot de passe', Routes.changePassword),
      (Icons.help_outline,     'Aide & Support',         null),
      (Icons.logout,           'Se déconnecter',         null),
    ];

    return Column(
      children: items
          .map((item) => ListTile(
                leading: Icon(item.$1, color: AppColors.primary),
                title:   Text(item.$2,
                    style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.grey500),
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  if (item.$2 == 'Se déconnecter') {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed(Routes.login);
                    }
                  } else if (item.$3 != null) {
                    Navigator.of(context).pushNamed(item.$3!);
                  }
                },
              ))
          .toList(),
    );
  }
}
