import 'package:flutter/material.dart';

import '../../database/evenements_repository.dart';
import '../../models/evenement.dart';
import '../../utils/aide_dates.dart';

/// Formulaire de création / modification d'un événement (CRUD complet).
class EcranFormulaireEvenement extends StatefulWidget {
  final Evenement? evenementExistant;
  final Future<void> Function()? onEnregistre;

  /// `restaurant_profiles.id` du restaurant connecté (intégration TableGo :
  /// le Module 3 utilisait son unique restaurant, id 1).
  final int restaurantId;

  const EcranFormulaireEvenement({
    super.key,
    required this.restaurantId,
    this.evenementExistant,
    this.onEnregistre,
  });

  @override
  State<EcranFormulaireEvenement> createState() =>
      _EcranFormulaireEvenementState();
}

class _EcranFormulaireEvenementState extends State<EcranFormulaireEvenement> {
  final _cleFormulaire = GlobalKey<FormState>();
  final _controleurTitre = TextEditingController();
  final _controleurDescription = TextEditingController();
  final _controleurPlaces = TextEditingController();

  late String _type;
  late DateTime _date;
  bool _enregistrementEnCours = false;

  bool get _modeModification => widget.evenementExistant != null;

  @override
  void initState() {
    super.initState();
    final e = widget.evenementExistant;
    _controleurTitre.text = e?.titre ?? '';
    _controleurDescription.text = e?.description ?? '';
    _controleurPlaces.text = e?.placesTotal.toString() ?? '20';
    _type = e?.type ?? Evenement.typeSoiree;
    _date = e != null ? DateTime.parse(e.date) : DateTime.now();
  }

  @override
  void dispose() {
    _controleurTitre.dispose();
    _controleurDescription.dispose();
    _controleurPlaces.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final dateChoisie = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
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
      final existant = widget.evenementExistant;
      final placesTotal = int.parse(_controleurPlaces.text.trim());

      // En modification, si le nombre de places total change, on ajuste
      // les places restantes dans la même proportion (on garde les places
      // déjà réservées).
      int placesRestantes;
      if (existant != null) {
        final placesPrises = existant.placesTotal - existant.placesRestantes;
        placesRestantes = (placesTotal - placesPrises).clamp(0, placesTotal);
      } else {
        placesRestantes = placesTotal;
      }

      final evenement = Evenement(
        id: existant?.id,
        restaurantId: widget.restaurantId,
        titre: _controleurTitre.text.trim(),
        type: _type,
        date: AideDates.versTexte(_date),
        description: _controleurDescription.text.trim(),
        placesTotal: placesTotal,
        placesRestantes: placesRestantes,
      );

      final db = EvenementsRepository.instance;
      if (_modeModification) {
        await db.modifierEvenement(evenement);
      } else {
        await db.insererEvenement(evenement);
      }
      await widget.onEnregistre?.call();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_modeModification
              ? 'Événement mis à jour.'
              : 'Événement « ${evenement.titre} » créé.'),
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
            ? 'Modifier l\'événement'
            : 'Nouvel événement'),
      ),
      body: Form(
        key: _cleFormulaire,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _controleurTitre,
              decoration: const InputDecoration(
                labelText: 'Titre',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Indiquez un titre' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type d\'événement',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: Evenement.typeAnniversaire,
                  child: Text('Anniversaire'),
                ),
                DropdownMenuItem(
                  value: Evenement.typeSoiree,
                  child: Text('Soirée'),
                ),
                DropdownMenuItem(
                  value: Evenement.typeMusiqueLive,
                  child: Text('Musique live'),
                ),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.calendar_today, color: Colors.deepOrange),
                title: const Text('Date'),
                subtitle:
                    Text(AideDates.formaterDateLongue(AideDates.versTexte(_date))),
                trailing: const Icon(Icons.chevron_right),
                onTap: _choisirDate,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controleurPlaces,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nombre de places total',
                prefixIcon: Icon(Icons.event_seat),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) {
                  return 'Indiquez un nombre de places (au moins 1)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controleurDescription,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
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
                  : 'Créer l\'événement'),
              onPressed: _enregistrementEnCours ? null : _enregistrer,
            ),
          ],
        ),
      ),
    );
  }
}
