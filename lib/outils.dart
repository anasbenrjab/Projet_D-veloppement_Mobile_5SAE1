// petites fonctions pour l'affichage

// 2026-10-15 -> 15/10/2026
String dateFr(String date) {
  List<String> p = date.split('-');
  if (p.length != 3) return date;
  return '${p[2]}/${p[1]}/${p[0]}';
}

// 10.0 -> 10 et 2.5 -> 2,5
String nombre(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString().replaceAll('.', ',');
}

// virgule comme en francais (charte figma) : virgule(4.8, 1) -> 4,8
// et virgule(54, 3) -> 54,000 pour les prix en TND
String virgule(double v, int decimales) {
  return v.toStringAsFixed(decimales).replaceAll('.', ',');
}

// positif -> Positif, negatif -> Négatif
String texteSentiment(String s) {
  if (s == 'positif') return 'Positif';
  if (s == 'negatif') return 'Négatif';
  return 'Neutre';
}
