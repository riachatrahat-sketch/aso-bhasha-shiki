/// Form validators. Each returns an error message, or null when valid.
class Validators {
  Validators._();

  static final _emailRe = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');

  static String? fullName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Please enter your full name';
    if (s.length < 2) return 'Name is too short';
    if (s.length > 60) return 'Name is too long';
    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Please enter your email address';
    if (!_emailRe.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  static String? gender(String? v) =>
      (v == null || v.isEmpty) ? 'Please select an option' : null;

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Please enter a password';
    if (s.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) {
      return 'Use letters and at least one number';
    }
    return null;
  }

  static String? confirmPassword(String? v, String password) {
    if ((v ?? '').isEmpty) return 'Please confirm your password';
    if (v != password) return 'Passwords do not match';
    return null;
  }

  static String? loginPassword(String? v) =>
      (v ?? '').isEmpty ? 'Please enter your password' : null;

  static String? terms(bool? accepted) =>
      accepted == true ? null : 'You must accept the Terms and Privacy Policy';
}
