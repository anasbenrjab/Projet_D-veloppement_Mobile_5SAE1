import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/reservation.dart';
import '../../models/resultats_ia.dart';
import '../../services/ai_service.dart';
import '../../utils/aide_dates.dart';
import '../../widgets/carte_meteo.dart';
import '../../widgets/feuille_creneaux_alternatifs.dart';

/// Formulaire de réservation, utilisé pour CRÉER et pour MODIFIER.
///
/// À l'enregistrement, l'IA locale intervient à deux endroits :
///   1. calcul du score de risque de no-show (stocké avec la réservation) ;
///   2. si le créneau demandé est complet, proposition de créneaux
///      alternatifs que le client peut choisir en un clic.
class EcranFormulaireReservation extends StatefulWidget {
  final int clientId;

  /// Non null : on modifie une réservation existante.
  final Reservation? reservationExistante;

  /// Callback exécuté par l'écran appelant après un enregistrement réussi.
  final Future<void> Function()? onEnregistre;

  const EcranFormulaireReservation({
    super.key,
    required this.clientId,
    this.reservationExistante,
    this.onEnregistre,
  });

  @override
  State<EcranFormulaireReservation> createState() =>
      _EcranFormulaireReservationState();
}

class _EcranFormulaireReservationState
    extends State<EcranFormulaireReservation> {
  final _cleFormulaire = GlobalKey<FormState>();
  final AiService _ia = AiService();

  late DateTime _date;
  late String _heure;
  late int _nbPersonnes;
  bool _enregistrementEnCours = false;

  /// Tous les créneaux proposés au client : de 12h00 à 22h00 par demi-heure.
  static List<String> get _creneaux {
    final liste = <String>[];
    for (var h = AideDates.heureOuverture; h <= AideDates.heureFermeture; h++) {
      liste.add('${h.toString().padLeft(2, '0')}:00');
      if (h < AideDates.heureFermeture) {
        liste.add('${h.toString().padLeft(2, '0')}:30');
      }
    }
    return liste;
  }

  bool get _modeModification => widget.reservationExistante != null;

  @override
  void initState() {
    super.initState();
    final existante = widget.reservationExistante;
    _date = existante != null
        ? DateTime.parse(existante.date)
        : DateTime.now();
    _heure = existante?.heure ?? '19:00';
    _nbPersonnes = existante?.nbPersonnes ?? 2;
  }

  Future<void> _choisirDate() async {
    final premiereDate =
        _modeModification ? DateTime.now() : DateTime.now();
    final dateChoisie = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: premiereDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr'),
    );
    if (dateChoisie != null) {
      setState(() => _date = dateChoisie);
    }
  }

  Future<void> _enregistrer() async {
    if (!_cleFormulaire.currentState!.validate()) return;
    setState(() => _enregistrementEnCours = true);

    try {
      final existante = widget.reservationExistante;
      final dateTexte = AideDates.versTexte(_date);

      // --- Étape IA n°2 : score de risque de no-show -----------------------
      // En modification, on compte les modifications DÉJÀ faites + celle-ci.
      final nbModifications = (existante?.nbModifications ?? 0) +
          (_modeModification ? 1 : 0);
      final score = await _ia.calculerScoreNoShow(
        clientId: widget.clientId,
        date: dateTexte,
        nbPersonnes: _nbPersonnes,
        nbModifications: nbModifications,
      );

      // --- Étape IA n°3 : créneau complet ? -> alternatives ----------------
      final complet = await _ia.creneauComplet(
        date: dateTexte,
        heure: _heure,
        nbPersonnes: _nbPersonnes,
      );
      String heureFinale = _heure;
      if (complet) {
        if (!mounted) return;
        final propositions = await _ia.proposerCreneauxAlternatifs(
          date: dateTexte,
          heure: _heure,
          nbPersonnes: _nbPersonnes,
        );
        if (!mounted) return;
        final choix = await FeuilleCreneauxAlternatifs.afficher(
          context,
          propositions: propositions,
        );
        if (choix == null) {
          // Feuille fermée sans choix : on abandonne l'enregistrement.
          if (mounted) setState(() => _enregistrementEnCours = false);
          return;
        }
        if (choix is CreneauPropose) {
          // Le client a adopté une proposition de l'IA en un clic.
          heureFinale = choix.heure;
        }
        // choix == 'maintenir' : on garde l'heure initiale.
      }

      // --- Enregistrement en base ------------------------------------------
      final reservation = Reservation(
        id: existante?.id,
        clientId: widget.clientId,
        restaurantId: 1,
        date: dateTexte,
        heure: heureFinale,
        nbPersonnes: _nbPersonnes,
        statut: existante?.statut ?? Reservation.statutEnAttente,
        nbModifications: nbModifications,
        scoreNoShow: score,
        createdAt: existante?.createdAt ?? AideDates.maintenantIso(),
      );

      if (_modeModification) {
        await DatabaseHelper.instance.modifierReservation(reservation);
      } else {
        await DatabaseHelper.instance.insererReservation(reservation);
      }
      await widget.onEnregistre?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _modeModification
                ? 'Réservation mise à jour (nouveau score IA : ${score.toStringAsFixed(2)}).'
                : 'Demande envoyée ! Le restaurant va la traiter.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'enregistrement : $e')),
      );
    } finally {
      if (mounted) setState(() => _enregistrementEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_modeModification
            ? 'Modifier la réservation'
            : 'Nouvelle réservation'),
      ),
      body: Form(
        key: _cleFormulaire,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Météo en direct (API externe Open-Meteo) ---------------
            const CarteMeteo(),
            const SizedBox(height: 12),

            // ---- Date --------------------------------------------------
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today,
                    color: Colors.deepOrange),
                title: const Text('Date'),
                subtitle: Text(AideDates.formaterDateLongue(
                    AideDates.versTexte(_date))),
                trailing: const Icon(Icons.chevron_right),
                onTap: _choisirDate,
              ),
            ),
            const SizedBox(height: 12),

            // ---- Heure -------------------------------------------------
            DropdownButtonFormField<String>(
              value: _heure,
              decoration: const InputDecoration(
                labelText: 'Heure',
                prefixIcon: Icon(Icons.schedule),
                border: OutlineInputBorder(),
              ),
              items: _creneaux
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: (v) => setState(() => _heure = v ?? _heure),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Choisissez une heure' : null,
            ),
            const SizedBox(height: 12),

            // ---- Nombre de personnes ------------------------------------
            DropdownButtonFormField<int>(
              value: _nbPersonnes,
              decoration: const InputDecoration(
                labelText: 'Nombre de personnes',
                prefixIcon: Icon(Icons.groups),
                border: OutlineInputBorder(),
              ),
              items: List.generate(20, (i) => i + 1)
                  .map((n) =>
                      DropdownMenuItem(value: n, child: Text('$n personne(s)')))
                  .toList(),
              onChanged: (v) => setState(() => _nbPersonnes = v ?? _nbPersonnes),
              validator: (v) =>
                  v == null ? 'Choisissez le nombre de personnes' : null,
            ),
            const SizedBox(height: 20),

            // ---- Bouton d'enregistrement ---------------------------------
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _enregistrementEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_modeModification
                  ? 'Enregistrer les modifications'
                  : 'Envoyer ma demande'),
              onPressed:
                  _enregistrementEnCours ? null : _enregistrer,
            ),
            const SizedBox(height: 8),
            if (_modeModification)
              const Text(
                'Chaque modification est comptabilisée : à partir de 2 '
                'modifications, le score de risque de no-show augmente.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
