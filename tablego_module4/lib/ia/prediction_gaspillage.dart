// IA du module 4 : prediction du gaspillage et idees de recettes
// 1) quantite a preparer chaque jour (a partir de l'historique des ventes)
// 2) idees de plats avec les ingredients proches de la peremption
// 3) prix de reduction juste pour les offres de derniere minute
// tout se fait dans l'application (pas besoin d'internet)

import '../models/ingredient.dart';
import '../models/vente.dart';

// resultat de la prediction pour un plat
class Prediction {
  String plat;
  int quantite; // a preparer
  int dejaPreparees; // ce qu'on prepare d'habitude
  double moyenneRestes; // portions jetees en moyenne par jour
  String explication;

  Prediction(this.plat, this.quantite, this.dejaPreparees, this.moyenneRestes,
      this.explication);

  // portions economisees par rapport a d'habitude
  int economie() {
    if (dejaPreparees > quantite) return dejaPreparees - quantite;
    return 0;
  }
}

// une recette proposee par l'IA
class IdeeRecette {
  String nom;
  List<String> urgents; // ingredients du stock qui expirent bientot
  List<String> enStock; // autres ingredients deja dans le stock
  List<String> manquants; // a acheter

  IdeeRecette(this.nom, this.urgents, this.enStock, this.manquants);
}

// resultat du prix suggere
class PrixSuggere {
  double prix;
  int pourcentage;
  List<String> raisons;

  PrixSuggere(this.prix, this.pourcentage, this.raisons);
}

class PredictionGaspillage {
  // ================= 1) QUANTITE A PREPARER =================

  // methode : moyenne ponderee des ventes du meme jour de la semaine
  // sur les 4 dernieres semaines (la semaine la plus recente compte plus)
  // + une petite marge de 10 % pour ne pas manquer
  static Prediction quantiteAPreparer(
      List<Vente> historique, String plat, DateTime jour) {
    // les ventes de ce plat, de la plus recente a la plus ancienne
    List<Vente> ventes = historique.where((v) => v.plat == plat).toList();
    ventes.sort((a, b) => b.date.compareTo(a.date));

    if (ventes.isEmpty) {
      return Prediction(plat, 0, 0, 0, 'Pas encore d\'historique pour ce plat');
    }

    // meme jour de la semaine (ex : tous les samedis)
    List<Vente> memeJour = ventes
        .where((v) => DateTime.parse(v.date).weekday == jour.weekday)
        .toList();
    if (memeJour.length > 4) memeJour = memeJour.sublist(0, 4);

    double somme = 0;
    double totalPoids = 0;
    String explication;

    if (memeJour.isNotEmpty) {
      List<int> poids = [4, 3, 2, 1];
      for (int i = 0; i < memeJour.length; i++) {
        int demande = memeJour[i].vendues;
        // si tout a ete vendu, les clients en voulaient peut-etre plus
        if (memeJour[i].vendues >= memeJour[i].preparees) demande = demande + 2;
        somme = somme + demande * poids[i];
        totalPoids = totalPoids + poids[i];
      }
      explication =
          'Moyenne des ${memeJour.length} derniers jours du même type (+10 % de marge)';
    } else {
      // pas de vente ce jour-la : moyenne simple de toutes les ventes
      for (Vente v in ventes) {
        somme = somme + v.vendues;
        totalPoids = totalPoids + 1;
      }
      explication = 'Moyenne de toutes les ventes (+10 % de marge)';
    }

    double moyenne = somme / totalPoids;
    int quantite = (moyenne * 1.1).ceil();

    // ce qu'on prepare d'habitude et ce qu'on jette en moyenne
    int dernieres = ventes.first.preparees;
    double restes = 0;
    for (Vente v in ventes) {
      restes = restes + v.restes();
    }
    restes = restes / ventes.length;

    return Prediction(plat, quantite, dernieres, restes, explication);
  }

  // la liste des plats differents de l'historique
  static List<String> plats(List<Vente> historique) {
    List<String> res = [];
    for (Vente v in historique) {
      if (!res.contains(v.plat)) res.add(v.plat);
    }
    res.sort();
    return res;
  }

  // ================= 2) IDEES DE RECETTES =================

  // petites recettes tunisiennes et simples : nom -> ingredients
  static Map<String, List<String>> recettes = {
    'Ojja merguez': ['tomate', 'poivron', 'oeuf', 'merguez', 'ail'],
    'Chakchouka': ['tomate', 'poivron', 'oignon', 'oeuf'],
    'Kafteji': ['poivron', 'tomate', 'courgette', 'oeuf', 'pomme de terre'],
    'Salade méchouia': ['poivron', 'tomate', 'oignon', 'ail', 'thon'],
    'Salade tunisienne': ['tomate', 'concombre', 'oignon', 'poivron', 'thon'],
    'Couscous aux légumes': [
      'semoule', 'carotte', 'courgette', 'pomme de terre', 'pois chiche'
    ],
    'Couscous au poulet': ['semoule', 'poulet', 'courgette', 'carotte', 'tomate'],
    'Brik à l\'oeuf': ['feuille de brick', 'oeuf', 'thon', 'pomme de terre'],
    'Lablabi': ['pois chiche', 'pain', 'ail', 'oeuf', 'cumin'],
    'Tajine tunisien': ['oeuf', 'fromage', 'poulet', 'pomme de terre'],
    'Soupe de légumes': ['carotte', 'courgette', 'pomme de terre', 'oignon'],
    'Gratin de pommes de terre': ['pomme de terre', 'lait', 'fromage'],
    'Riz au poulet': ['riz', 'poulet', 'tomate', 'oignon'],
    'Pâtes au thon': ['pates', 'thon', 'tomate', 'ail'],
    'Omelette au fromage': ['oeuf', 'fromage', 'lait'],
  };

  // minuscules, sans accents, sans le "s" du pluriel
  static String nettoyer(String texte) {
    String t = texte.toLowerCase().trim();
    t = t.replaceAll(RegExp('[àâä]'), 'a');
    t = t.replaceAll(RegExp('[éèêë]'), 'e');
    t = t.replaceAll(RegExp('[îï]'), 'i');
    t = t.replaceAll(RegExp('[ôö]'), 'o');
    t = t.replaceAll(RegExp('[ùûü]'), 'u');
    t = t.replaceAll('ç', 'c');
    t = t.replaceAll('œ', 'oe');
    if (t.endsWith('s')) t = t.substring(0, t.length - 1);
    return t;
  }

  // "Tomates cerises" correspond a "tomate"
  static bool correspond(String nomStock, String ingredientRecette) {
    String a = nettoyer(nomStock);
    String b = nettoyer(ingredientRecette);
    return a.contains(b) || b.contains(a);
  }

  // cherche le nom de l'ingredient du stock qui correspond, sinon null
  static Ingredient? chercher(List<Ingredient> stock, String ingredientRecette) {
    for (Ingredient i in stock) {
      if (correspond(i.nom, ingredientRecette)) return i;
    }
    return null;
  }

  // on garde les recettes qui utilisent au moins 1 ingredient urgent
  // tri : d'abord le plus d'ingredients urgents, puis le moins a acheter
  static List<IdeeRecette> idees(List<Ingredient> stock) {
    // un ingredient deja perime ne doit pas etre cuisine
    List<Ingredient> utilisables = stock.where((i) => !i.estPerime()).toList();

    List<IdeeRecette> res = [];
    recettes.forEach((nom, ingredients) {
      List<String> urgents = [];
      List<String> enStock = [];
      List<String> manquants = [];
      for (String ing in ingredients) {
        Ingredient? trouve = chercher(utilisables, ing);
        if (trouve == null) {
          manquants.add(ing);
        } else if (trouve.expireBientot()) {
          urgents.add(trouve.nom);
        } else {
          enStock.add(trouve.nom);
        }
      }
      if (urgents.isNotEmpty) {
        res.add(IdeeRecette(nom, urgents, enStock, manquants));
      }
    });

    res.sort((a, b) {
      if (a.urgents.length != b.urgents.length) {
        return b.urgents.length - a.urgents.length;
      }
      return a.manquants.length - b.manquants.length;
    });
    return res;
  }

  // ================= 3) PRIX DE REDUCTION JUSTE =================

  // on part de -30 % puis on ajoute selon la situation, maximum -60 %
  // (en dessous on vend a perte, ce n'est plus juste pour le restaurant)
  static PrixSuggere prixSuggere(
      double prixInitial, int minutesAvantFin, int quantite) {
    int pourcentage = 30;
    List<String> raisons = ['Base anti-gaspi : -30 %'];

    if (minutesAvantFin <= 60) {
      pourcentage = pourcentage + 15;
      raisons.add('Moins d\'une heure avant la fin : +15 %');
    } else if (minutesAvantFin <= 120) {
      pourcentage = pourcentage + 5;
      raisons.add('Moins de 2 heures avant la fin : +5 %');
    }

    if (quantite >= 10) {
      pourcentage = pourcentage + 10;
      raisons.add('Beaucoup de portions ($quantite) : +10 %');
    } else if (quantite >= 5) {
      pourcentage = pourcentage + 5;
      raisons.add('$quantite portions à écouler : +5 %');
    }

    if (pourcentage > 60) {
      pourcentage = 60;
      raisons.add('Plafond : -60 % maximum');
    }

    // arrondi au 0,5 TND le plus proche (plus facile a payer)
    double prix = prixInitial * (100 - pourcentage) / 100;
    prix = (prix * 2).round() / 2;
    if (prix <= 0) prix = 0.5;

    return PrixSuggere(prix, pourcentage, raisons);
  }
}
