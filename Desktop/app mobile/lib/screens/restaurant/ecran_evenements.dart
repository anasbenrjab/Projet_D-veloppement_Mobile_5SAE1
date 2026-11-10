import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/evenement.dart';
import '../../utils/aide_dates.dart';
import '../../widgets/etat_vide.dart';
import 'ecran_formulaire_evenement.dart';

/// Onglet "Événements" du restaurant : CRUD complet (créer, lister,
/// modifier, supprimer) avec la jauge des places restantes.
class EcranEvenements extends StatefulWidget {
  const EcranEvenements({super.key});

  @override
  State<EcranEvenements> createState() => _EcranEvenementsState();
}

class _EcranEvenementsState extends State<EcranEvenements>
    with AutomaticKeepAliveClientMixin {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Evenement> _evenements = [];
  bool _chargement = true;
  String? _erreur;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final liste = await _db.evenements();
      if (!mounted) return;
      setState(() => _evenements = liste);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.toString());
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _supprimer(Evenement e) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'événement ?'),
        content: Text('« ${e.titre} » sera définitivement supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    try {
      await _db.supprimerEvenement(e.id!);
      await _charger();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Événement « ${e.titre} » supprimé.')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $err')),
      );
    }
  }

  IconData _iconeType(String type) {
    switch (type) {
      case Evenement.typeAnniversaire:
        return Icons.cake;
      case Evenement.typeSoiree:
        return Icons.celebration;
      case Evenement.typeMusiqueLive:
        return Icons.music_note;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nouvel_evenement',
        icon: const Icon(Icons.add),
        label: const Text('Événement'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EcranFormulaireEvenement(onEnregistre: _charger),
            ),
          );
        },
      ),
      body: _construireListe(),
    );
  }

  Widget _construireListe() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return EtatVide(
        icone: Icons.error_outline,
        titre: 'Une erreur est survenue',
        message: _erreur!,
      );
    }
    if (_evenements.isEmpty) {
      return const EtatVide(
        icone: Icons.celebration,
        titre: 'Aucun événement',
        message: 'Créez votre premier événement avec le bouton « Événement ».',
      );
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: _evenements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final e = _evenements[index];
          final progression = e.placesTotal > 0
              ? (e.placesTotal - e.placesRestantes) / e.placesTotal
              : 0.0;
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EcranFormulaireEvenement(
                    evenementExistant: e,
                    onEnregistre: _charger,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.deepOrange.shade50,
                      child: Icon(_iconeType(e.type),
                          color: Colors.deepOrange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.titre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${Evenement.libellesTypes[e.type] ?? e.type} · '
                            '${AideDates.formaterDateLongue(e.date)}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: progression.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${e.placesRestantes}/${e.placesTotal} places',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'Modifier',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EcranFormulaireEvenement(
                                evenementExistant: e,
                                onEnregistre: _charger,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          tooltip: 'Supprimer',
                          onPressed: () => _supprimer(e),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
