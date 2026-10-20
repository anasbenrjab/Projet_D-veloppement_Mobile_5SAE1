import 'dart:convert';

/// Parses a value that may be:
///   - null                          → returns []
///   - a real List                   → returns `List<String>`
///   - a JSON-encoded String array   → decodes and returns `List<String>`
///   - anything else                 → returns []
///
/// Use for: dietary_preferences, allergies, photos, tags
List<String> parseStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((e) => e.toString()).toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
    } catch (_) {}
  }
  return const [];
}

/// Parses a value that may be:
///   - null                          → returns {}
///   - a real Map                    → returns `Map<String, dynamic>`
///   - a JSON-encoded String object  → decodes and returns `Map<String, dynamic>`
///   - anything else                 → returns {}
///
/// Use for: opening_hours
Map<String, dynamic> parseJsonMap(dynamic value) {
  if (value == null) return const {};
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return const {};
}

/// Parses a value that may be a List or a JSON-encoded String list,
/// preserving the element type (Map, String, etc.).
///
/// Use for: matching_dishes or other heterogeneous arrays
List<dynamic> parseDynamicList(dynamic value) {
  if (value == null) return const [];
  if (value is List) return value;
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
    } catch (_) {}
  }
  return const [];
}
