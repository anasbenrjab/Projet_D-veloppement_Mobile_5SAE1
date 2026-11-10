// utilisateur connecte (le login c'est le module 1)
// pour le moment on met des valeurs fixes pour tester

String role = 'restaurant'; // 'client' ou 'restaurant'
int userId = 1;
String userNom = 'Dar El Jeld';
int restaurantId = 1;
String restaurantNom = 'Dar El Jeld';
String heureFermeture = '23:00'; // fin du service du restaurant

void changerRole(String r) {
  role = r;
  if (r == 'restaurant') {
    userId = 1;
    userNom = 'Dar El Jeld';
  } else {
    userId = 2;
    userNom = 'Mouhib';
  }
}
