// utilisateur connecte (le login c'est le module 1)
// pour le moment on met des valeurs fixes pour tester

String role = 'client'; // 'client' ou 'restaurant'
int userId = 2;
String userNom = 'Mouhib';
int restaurantId = 1;
String restaurantNom = 'Dar El Jeld';

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
