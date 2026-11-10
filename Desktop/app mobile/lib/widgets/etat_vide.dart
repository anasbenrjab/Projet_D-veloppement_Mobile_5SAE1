import 'package:flutter/material.dart';

/// Widget d'état vide réutilisable (liste sans données, aucun créneau...).
class EtatVide extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String message;

  const EtatVide({
    super.key,
    required this.icone,
    required this.titre,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              titre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
