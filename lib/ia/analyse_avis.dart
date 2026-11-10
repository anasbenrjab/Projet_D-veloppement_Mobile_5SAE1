// IA du module 5 : analyse des avis
// 1) sentiment : positif / neutre / negatif
// 2) detection spam et mots offensants
// tout se fait dans l'application (pas besoin d'internet)

class AnalyseAvis {
  static List<String> motsPositifs = [
    'bon', 'bonne', 'bons', 'excellent', 'excellente', 'delicieux',
    'delicieuse', 'parfait', 'parfaite', 'super', 'genial', 'top',
    'magnifique', 'agreable', 'sympa', 'rapide', 'propre', 'frais',
    'savoureux', 'genereux', 'recommande', 'adore', 'aime', 'merci',
    'bravo', 'meilleur', 'impeccable', 'chaleureux', 'gentil',
    'good', 'great', 'delicious', 'amazing', 'perfect', 'nice', 'love',
    'best', 'tasty', 'friendly', 'recommend',
    'behi', 'bnin', 'mezyen', 'saha', // tunisien
  ];

  static List<String> motsNegatifs = [
    'mauvais', 'mauvaise', 'nul', 'nulle', 'horrible', 'degoutant',
    'decu', 'decue', 'decevant', 'froid', 'froide', 'lent', 'lente',
    'sale', 'cher', 'attente', 'retard', 'pire', 'eviter', 'fade',
    'impoli', 'catastrophe', 'arnaque', 'probleme', 'terrible',
    'bad', 'awful', 'cold', 'slow', 'rude', 'dirty', 'worst',
    'disappointed', 'expensive',
    'khayeb', 'khayba', // tunisien
  ];

  static List<String> negations = [
    'pas', 'ne', 'n', 'jamais', 'aucun', 'not', 'no', 'never',
    'mouch', 'mech',
  ];

  static List<String> motsSpam = [
    'gratuit', 'free', 'cliquez', 'click', 'gagnez', 'gagner', 'win',
    'bitcoin', 'crypto', 'whatsapp', 'telegram', 'argent', 'casino',
  ];

  static List<String> insultes = [
    'con', 'connard', 'salaud', 'merde', 'putain', 'idiot', 'imbecile',
    'debile', 'cretin', 'stupide', 'abruti', 'fuck', 'shit', 'stupid',
    'bitch', 'hmar', 'kalb',
  ];

  // met le texte en minuscule, enleve les accents et la ponctuation
  static String nettoyer(String texte) {
    String t = texte.toLowerCase();
    t = t.replaceAll(RegExp('[àâä]'), 'a');
    t = t.replaceAll(RegExp('[éèêë]'), 'e');
    t = t.replaceAll(RegExp('[îï]'), 'i');
    t = t.replaceAll(RegExp('[ôö]'), 'o');
    t = t.replaceAll(RegExp('[ùûü]'), 'u');
    t = t.replaceAll('ç', 'c');
    t = t.replaceAll(RegExp('[^a-z0-9 ]'), ' ');
    t = t.replaceAll(RegExp(' +'), ' ');
    return t.trim();
  }

  static String sentiment(String commentaire, int note) {
    List<String> mots = nettoyer(commentaire).split(' ');
    int score = 0;

    for (int i = 0; i < mots.length; i++) {
      int valeur = 0;
      if (motsPositifs.contains(mots[i])) valeur = 1;
      if (motsNegatifs.contains(mots[i])) valeur = -1;

      if (valeur != 0) {
        // si il y a une negation juste avant on inverse (ex: "pas bon")
        bool negation = false;
        if (i > 0 && negations.contains(mots[i - 1])) negation = true;
        if (i > 1 && negations.contains(mots[i - 2])) negation = true;
        // "j'aime pas" -> negation
        // mais "bon, pas cher" -> non, ici le "pas" va avec "cher"
        if (i < mots.length - 1 && mots[i + 1] == 'pas') {
          bool motApres = false;
          if (i < mots.length - 2) {
            String m = mots[i + 2];
            if (motsPositifs.contains(m) || motsNegatifs.contains(m)) {
              motApres = true;
            }
          }
          if (!motApres) negation = true;
        }

        if (negation) valeur = -valeur;
        score = score + valeur;
      }
    }

    // la note en etoiles compte aussi
    if (note >= 4) score++;
    if (note <= 2) score--;

    if (score > 0) return 'positif';
    if (score < 0) return 'negatif';
    return 'neutre';
  }

  static bool estSpam(String commentaire) {
    String t = commentaire.toLowerCase();

    // lien
    if (t.contains('http') || t.contains('www.') || t.contains('.com')) {
      return true;
    }
    // numero de telephone (8 chiffres)
    String sansEspaces = t.replaceAll(' ', '');
    if (RegExp('[0-9]{8}').hasMatch(sansEspaces)) {
      return true;
    }

    List<String> mots = nettoyer(commentaire).split(' ');

    // mots de pub
    int nb = 0;
    for (String m in mots) {
      if (motsSpam.contains(m)) nb++;
    }
    if (nb >= 2) return true;

    // le meme mot repete plein de fois
    if (mots.length >= 6 && mots.toSet().length <= mots.length / 2) {
      return true;
    }
    return false;
  }

  static bool estOffensant(String texte) {
    List<String> mots = nettoyer(texte).split(' ');
    for (String m in mots) {
      if (insultes.contains(m)) return true;
    }
    return false;
  }
}
