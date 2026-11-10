import 'package:flutter/material.dart';
import '../couleurs.dart';

// petite etiquette de couleur selon les jours avant peremption
// rouge = perime, orange = 3 jours ou moins, vert = ok
class BadgePeremption extends StatelessWidget {
  final int jours;
  const BadgePeremption({super.key, required this.jours});

  @override
  Widget build(BuildContext context) {
    String texte;
    Color fond;
    Color couleur;

    if (jours < 0) {
      texte = 'Périmé';
      fond = rougeClair;
      couleur = rouge;
    } else if (jours == 0) {
      texte = "Expire aujourd'hui";
      fond = orangeClair;
      couleur = orange;
    } else if (jours <= 3) {
      texte = 'Expire dans $jours j';
      fond = orangeClair;
      couleur = orange;
    } else {
      texte = '$jours jours';
      fond = vertClair;
      couleur = vert;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texte,
          style: TextStyle(
              color: couleur, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
