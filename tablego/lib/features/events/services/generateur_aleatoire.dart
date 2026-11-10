/// Petit générateur pseudo-aléatoire avec graine fixe (algorithme "mulberry32").
///
/// Pourquoi ne pas utiliser `dart:math.Random()` ? Parce qu'avec une graine
/// fixe (42), les données de démonstration sont toujours identiques d'un
/// lancement à l'autre : la démo est reproductible et explicable à l'oral.
///
/// Détail technique important : on utilise les bits de poids FORTS du
/// générateur (`>>> 8`) car les bits de poids faibles d'un tel générateur
/// ont un cycle très court et produiraient des tirages biaisés (par exemple
/// toujours le même client).
class GenerateurAleatoireSeedee {
  int _etat;

  GenerateurAleatoireSeedee(this._etat);

  int _suivant() {
    // Mulberry32 : générateur compact de bonne qualité (32 bits).
    _etat = (_etat + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _etat;
    t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF;
    t = (t ^ (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  /// Entier aléatoire entre 0 (inclus) et [max] (exclu).
  int nextInt(int max) => max <= 0 ? 0 : (_suivant() >>> 8) % max;

  /// Vrai ou faux avec 50 % de chances chacun.
  bool nextBool() => _suivant() >>> 31 == 1;
}
