import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'database/database_helper.dart';
import 'screens/ecran_choix_role.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Deux façons d'accéder à SQLite selon la plateforme :
  //   - sur Android, sqflite utilise SQLite natif : rien à faire ;
  //   - dans un navigateur, il n'existe pas de SQLite natif : on bascule
  //     sur la fabrique WebAssembly de sqflite_common_ffi_web.
  // Le reste de l'application (DatabaseHelper, IA, écrans) est identique.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  try {
    // Ouvre la base dès le démarrage : au premier lancement, cela crée les
    // tables et insère les 250 réservations fictives + les 3 événements.
    await DatabaseHelper.instance.database;
  } catch (e) {
    // Si la base échoue ici, l'écran d'accueil s'ouvre quand même : chaque
    // écran réessaie et affiche les erreurs proprement à l'utilisateur.
  }

  runApp(const RestoEventsApp());
}

/// Application principale : thème Material 3 en français, écran de choix
/// du rôle (restaurant ou client) comme point d'entrée.
class RestoEventsApp extends StatelessWidget {
  const RestoEventsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resto Events',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr'), Locale('en')],
      home: const EcranChoixRole(),
    );
  }
}
