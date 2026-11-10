// utilisateur connecte et restaurant affiche
// ces valeurs sont remplies par module4_entrees.dart a partir du login
// du module 1 (avant, on mettait des valeurs fixes pour tester)

String role = 'restaurant'; // 'client' ou 'restaurant'
int userId = 0; // users.id
String userNom = '';
int restaurantId = 0; // restaurant_profiles.id
String restaurantNom = '';
String heureFermeture = '23:00'; // fin du service du restaurant

void connecter(String r, int idUser, String nomUser, int idResto, String nomResto) {
  role = r;
  userId = idUser;
  userNom = nomUser;
  restaurantId = idResto;
  restaurantNom = nomResto;
}
