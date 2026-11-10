import 'package:flutter/material.dart';

/// Badge coloré affichant le risque de no-show calculé par l'IA :
///   - score < 0.3  -> "Faible"  (vert)
///   - score <= 0.6 -> "Moyen"   (orange)
///   - score > 0.6  -> "Élevé"   (rouge)
class BadgeNoShow extends StatelessWidget {
  final double score;

  const BadgeNoShow({super.key, required this.score});

  (String, Color) get _niveau {
    if (score < 0.3) return ('Faible', Colors.green);
    if (score <= 0.6) return ('Moyen', Colors.orange);
    return ('Élevé', Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    final (libelle, couleur) = _niveau;
    return Tooltip(
      message: 'Score de risque de no-show : ${score.toStringAsFixed(2)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: couleur.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: couleur),
        ),
        child: Text(
          'Risque $libelle',
          style: TextStyle(
            color: couleur,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
