import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/json_utils.dart';
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
    Future.microtask(() => ref.read(profileProvider.notifier).loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);

    if (state.isLoading && state.data == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final profile = state.data ?? {};
    final name = profile['full_name'] ?? 'Utilisateur';
    final email = profile['email'] ?? '';
    final phone = profile['phone'] ?? '';
    final photoUrl = profile['photo_url'];
    final prefs = parseStringList(profile['dietary_preferences']);
    final allergies = parseStringList(profile['allergies']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.of(context).pushNamed('/edit-client-profile');
              ref.read(profileProvider.notifier).loadProfile();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar + Name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl as String)
                        : null,
                    child: photoUrl == null
                        ? const Icon(Icons.person,
                            size: 52, color: AppColors.primary)
                        : null,
                  ),
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
            // Stats row
            Row(
              children: [
                _StatCard(icon: Icons.favorite, label: 'Favoris', value: '—'),
                const SizedBox(width: 12),
                _StatCard(
                    icon: Icons.location_on_outlined,
                    label: 'Adresses',
                    value: '—'),
                const SizedBox(width: 12),
                _StatCard(
                    icon: Icons.emoji_events_outlined,
                    label: 'Badges',
                    value: '—'),
              ],
            ),
            const SizedBox(height: 24),
            // Info card
            _InfoSection(
              title: 'Informations',
              children: [
                _InfoRow(icon: Icons.phone_outlined, text: phone.isEmpty ? 'Non renseigné' : phone),
                _InfoRow(icon: Icons.email_outlined, text: email),
              ],
            ),
            const SizedBox(height: 16),
            // Dietary preferences
            if (prefs.isNotEmpty) ...[
              _SectionHeader(title: 'Préférences alimentaires'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: prefs
                    .map((p) => _PreferenceChip(label: p, color: AppColors.eco))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            // Allergies
            if (allergies.isNotEmpty) ...[
              _SectionHeader(title: 'Allergies'),
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
            // Menu items
            _MenuList(),
          ],
        ),
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600));
  }
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
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
      (Icons.favorite_border, 'Mes favoris', '/favorites'),
      (Icons.lock_outline, 'Changer le mot de passe', '/change-password'),
      (Icons.help_outline, 'Aide & Support', null),
      (Icons.logout, 'Se déconnecter', null),
    ];

    return Column(
      children: items
          .map((item) => ListTile(
                leading: Icon(item.$1, color: AppColors.primary),
                title: Text(item.$2,
                    style: const TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right,
                    color: AppColors.grey500),
                contentPadding: EdgeInsets.zero,
                onTap: () async {
                  if (item.$2 == 'Se déconnecter') {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      Navigator.of(context)
                          .pushReplacementNamed('/login');
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
