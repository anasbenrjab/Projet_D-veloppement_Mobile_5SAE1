import 'package:flutter/material.dart';
import 'couleurs.dart';
import 'screens/home_page.dart';
import 'screens/ajout_avis_page.dart';
import 'screens/ajout_promotion_page.dart';
import 'screens/code_promo_page.dart';

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
        appBarTheme: const AppBarTheme(
          backgroundColor: creme,
          foregroundColor: brun,
          titleTextStyle: TextStyle(
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
        '/ajoutAvis': (context) => const AjoutAvisPage(),
        '/ajoutPromotion': (context) => const AjoutPromotionPage(),
        '/codePromo': (context) => const CodePromoPage(),
      },
    );
  }
}
