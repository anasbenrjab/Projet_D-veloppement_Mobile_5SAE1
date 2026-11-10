import 'dart:convert';
import 'package:http/http.dart' as http;

// API externe gratuite (MyMemory) pour traduire un avis en anglais
// exemple : https://api.mymemory.translated.net/get?q=Bonjour&langpair=fr|en
// reponse JSON : {"responseData": {"translatedText": "Hello"}, ...}
class TraductionApi {
  static Future<String> traduire(String texte) async {
    String url = 'https://api.mymemory.translated.net/get'
        '?q=${Uri.encodeComponent(texte)}&langpair=fr|en';

    http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      return data['responseData']['translatedText'];
    }
    throw Exception('Erreur ${response.statusCode}');
  }
}
