// petites fonctions pour l'affichage et les dates

// 2026-10-15 -> 15/10/2026
String dateFr(String date) {
  List<String> p = date.split('-');
  if (p.length != 3) return date;
  return '${p[2]}/${p[1]}/${p[0]}';
}

// DateTime -> 2026-10-15 (format qu'on garde dans la base)
String formatDate(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// date d'aujourd'hui sans l'heure
DateTime aujourdhui() {
  DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

// nombre de jours entre aujourd'hui et une date (negatif = date passee)
int joursRestants(String date) {
  return DateTime.parse(date).difference(aujourdhui()).inDays;
}

// 10.0 -> 10 et 2.5 -> 2,5
String nombre(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString().replaceAll('.', ',');
}

// virgule comme en francais : virgule(54, 3) -> 54,000 (prix en TND)
String virgule(double v, int decimales) {
  return v.toStringAsFixed(decimales).replaceAll('.', ',');
}

// "23:00" -> nombre de minutes depuis minuit (1380)
int minutes(String heure) {
  List<String> p = heure.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

// heure et minute -> texte : (9, 5) -> "09:05"
String formatHeure(int h, int m) {
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

// lundi = 1 ... dimanche = 7 (comme DateTime.weekday)
String nomJour(int jour) {
  List<String> jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
  ];
  return jours[jour - 1];
}
