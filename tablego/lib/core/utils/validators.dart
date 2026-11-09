/// Email and password rules shared by the forms and the repositories, so the
/// UI and the data layer can never disagree.
///
/// Each `*Error` method returns a French message, or `null` when the value is
/// valid; that is the signature [FormField.validator] expects.
class Validators {
  Validators._();

  /// Minimum password length.
  static const int minPasswordLength = 8;

  /// `local@domain.tld`: no spaces, one `@`, a dot-separated domain and a
  /// top-level domain of at least two letters.
  static final RegExp _email = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$',
  );

  /// Any letter, accented ones included.
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _digit = RegExp(r'\d');

  static bool isValidEmail(String email) => _email.hasMatch(email.trim());

  static String? emailError(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email requis';
    if (!isValidEmail(v)) return 'Format d\'email invalide';
    return null;
  }

  /// Rule: at least [minPasswordLength] characters, one letter and one digit.
  static String? passwordError(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Mot de passe requis';
    if (v.length < minPasswordLength) {
      return 'Au moins $minPasswordLength caractères';
    }
    if (!_letter.hasMatch(v) || !_digit.hasMatch(v)) {
      return 'Au moins une lettre et un chiffre';
    }
    return null;
  }
}
