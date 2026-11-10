import 'package:flutter/material.dart';

import '../models/reservation.dart';

/// Pastille colorée affichant le statut d'une réservation en français.
class PastilleStatut extends StatelessWidget {
  final String statut;

  const PastilleStatut({super.key, required this.statut});

  (String, Color) get _donnees {
    switch (statut) {
      case Reservation.statutEnAttente:
        return ('En attente', Colors.orange);
      case Reservation.statutAcceptee:
        return ('Acceptée', Colors.green);
      case Reservation.statutRefusee:
        return ('Refusée', Colors.red);
      case Reservation.statutAnnulee:
        return ('Annulée', Colors.blueGrey);
      case Reservation.statutHonoree:
        return ('Honorée', Colors.blue);
      case Reservation.statutNoShow:
        return ('No-show', Colors.deepPurple);
      default:
        return (statut, Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (libelle, couleur) = _donnees;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        libelle,
        style: TextStyle(
          color: couleur,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
