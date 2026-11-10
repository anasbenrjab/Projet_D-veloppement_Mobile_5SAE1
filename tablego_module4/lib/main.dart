import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'couleurs.dart';
import 'screens/home_page.dart';
import 'screens/ajout_ingredient_page.dart';
import 'screens/ajout_perte_page.dart';
import 'screens/ajout_offre_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TableGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: orange, primary: orange),
        scaffoldBackgroundColor: creme,
        // police Poppins (charte figma, comme les autres modules)
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: creme,
          foregroundColor: brun,
          titleTextStyle: GoogleFonts.poppins(
              color: brun, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        // charte figma : cartes arrondies 16, boutons et champs arrondis 12
        cardTheme: CardThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/ajoutIngredient': (context) => const AjoutIngredientPage(),
        '/ajoutPerte': (context) => const AjoutPertePage(),
        '/ajoutOffre': (context) => const AjoutOffrePage(),
      },
    );
  }
}
