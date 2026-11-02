/// Normalised vocabulary for diets, dish tags, allergens and cuisines.
///
/// Every label — whether it comes from the client profile (stored with the
/// profile screen's English values such as `vegetarian`, `peanuts`, `dairy`)
/// or from a dish (`["vegetarien"]`, `["arachides","lactose"]`) — is reduced
/// to one canonical form before any comparison:
///
/// * lowercase, accents removed, `-` `_` `'` turned into spaces, single
///   spaces (`"Végétarien"` → `vegetarien`, `"fruits-à-coque"` →
///   `fruits a coque`);
/// * known synonyms, English or French, mapped to the French canonical
///   name (`peanuts` / `cacahuète` → `arachides`, `dairy` / `lait` →
///   `lactose`).
///
/// The canonical names are the storage format documented for Module 2 in
/// docs/integration-recommandations.md.
class FoodLabels {
  FoodLabels._();

  // ── Normalisation ─────────────────────────────────────────────────────────

  static const _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae',
  };

  /// Lowercase, accent-free, single-spaced form of [raw].
  static String normalize(String raw) {
    final lower = raw.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_accents[ch] ?? ch);
    }
    return buffer
        .toString()
        // Combining accents (decomposed input such as "é").
        .replaceAll(RegExp('[̀-ͯ]'), '')
        .replaceAll(RegExp(r"[-_'’]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Synonyms (already normalised) → canonical French name.
  static const _synonyms = {
    // Diets
    'halal': 'halal',
    'vegetarien': 'vegetarien',
    'vegetarienne': 'vegetarien',
    'vegetarian': 'vegetarien',
    'veggie': 'vegetarien',
    'vegan': 'vegan',
    'vegane': 'vegan',
    'vegetalien': 'vegan',
    'vegetalienne': 'vegan',
    'pescetarien': 'pescetarien',
    'pescatarien': 'pescetarien',
    'pescatarian': 'pescetarien',
    'pescetarian': 'pescetarien',
    'sans gluten': 'sans gluten',
    'gluten free': 'sans gluten',
    'casher': 'casher',
    'cacher': 'casher',
    'kasher': 'casher',
    'kosher': 'casher',
    // Allergens
    'arachides': 'arachides',
    'arachide': 'arachides',
    'peanuts': 'arachides',
    'peanut': 'arachides',
    'cacahuetes': 'arachides',
    'cacahuete': 'arachides',
    'gluten': 'gluten',
    'ble': 'gluten',
    'wheat': 'gluten',
    'lactose': 'lactose',
    'lait': 'lactose',
    'milk': 'lactose',
    'dairy': 'lactose',
    'produits laitiers': 'lactose',
    'oeufs': 'oeufs',
    'oeuf': 'oeufs',
    'eggs': 'oeufs',
    'egg': 'oeufs',
    'soja': 'soja',
    'soy': 'soja',
    'soya': 'soja',
    'crustaces': 'crustaces',
    'crustace': 'crustaces',
    'shellfish': 'crustaces',
    'fruits de mer': 'crustaces',
    'fruits a coque': 'fruits a coque',
    'tree nuts': 'fruits a coque',
    'nuts': 'fruits a coque',
    'noix': 'fruits a coque',
    'poisson': 'poisson',
    'fish': 'poisson',
    'sesame': 'sesame',
    'moutarde': 'moutarde',
    'mustard': 'moutarde',
    'celeri': 'celeri',
    'celery': 'celeri',
  };

  /// Canonical French name of [raw]; unknown labels stay normalised as-is.
  static String canonical(String raw) {
    final n = normalize(raw);
    return _synonyms[n] ?? n;
  }

  /// Canonical, de-duplicated set of [raw] labels (empty strings dropped).
  static Set<String> canonicalSet(Iterable<String> raw) =>
      raw.map(canonical).where((s) => s.isNotEmpty).toSet();

  // ── Diet rules ────────────────────────────────────────────────────────────

  /// Diets the recommender enforces.  Any other value in a profile is
  /// ignored rather than silently emptying every list.
  static const knownDiets = {
    'halal', 'vegetarien', 'vegan', 'pescetarien', 'sans gluten', 'casher',
  };

  /// Whether a dish with canonical [tags] and [allergens] (null = not
  /// declared) is compatible with the canonical [diet].
  ///
  /// A dish must carry the diet's tag, except that a vegan dish is also
  /// vegetarian, a vegetarian dish is also pescetarian, and a dish whose
  /// declared allergens exclude gluten is gluten-free.
  static bool satisfiesDiet(
      String diet, Set<String> tags, Set<String>? allergens) {
    switch (diet) {
      case 'vegetarien':
        return tags.contains('vegetarien') || tags.contains('vegan');
      case 'pescetarien':
        return tags.contains('pescetarien') ||
            tags.contains('vegetarien') ||
            tags.contains('vegan');
      case 'sans gluten':
        return tags.contains('sans gluten') ||
            (allergens != null && !allergens.contains('gluten'));
      default:
        return tags.contains(diet);
    }
  }

  // ── French display ────────────────────────────────────────────────────────

  static const _display = {
    'halal': 'halal',
    'vegetarien': 'végétarien',
    'vegan': 'vegan',
    'pescetarien': 'pescétarien',
    'sans gluten': 'sans gluten',
    'casher': 'casher',
    'arachides': 'arachides',
    'gluten': 'gluten',
    'lactose': 'lactose',
    'oeufs': 'œufs',
    'soja': 'soja',
    'crustaces': 'crustacés',
    'fruits a coque': 'fruits à coque',
    'poisson': 'poisson',
    'sesame': 'sésame',
    'moutarde': 'moutarde',
    'celeri': 'céleri',
  };

  /// French label for a canonical diet, tag or allergen.
  static String display(String canonical) => _display[canonical] ?? canonical;

  static const _cuisines = {
    'french': 'française',
    'francaise': 'française',
    'american': 'américaine',
    'americaine': 'américaine',
    'japanese': 'japonaise',
    'japonaise': 'japonaise',
    'italian': 'italienne',
    'italienne': 'italienne',
    'lebanese': 'libanaise',
    'libanaise': 'libanaise',
    'chinese': 'chinoise',
    'chinoise': 'chinoise',
    'indian': 'indienne',
    'indienne': 'indienne',
    'mexican': 'mexicaine',
    'mexicaine': 'mexicaine',
    'moroccan': 'marocaine',
    'marocaine': 'marocaine',
    'tunisian': 'tunisienne',
    'tunisienne': 'tunisienne',
  };

  /// French adjective for a cuisine type ("Japanese" → "japonaise").
  static String cuisineDisplay(String cuisine) {
    final n = normalize(cuisine);
    return _cuisines[n] ?? n;
  }

  /// French enumeration: `[a]` → "a", `[a, b]` → "a et b",
  /// `[a, b, c]` → "a, b et c".
  static String joinFr(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join(', ')} et ${items.last}';
  }
}
