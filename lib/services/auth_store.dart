import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local account storage for the prototype.
///
/// There is no backend yet, so registered accounts live in SharedPreferences
/// on the device. Passwords are stored as-is — this is NOT real security,
/// it only keeps honest people honest on a single device. When the backend
/// lands, this whole file is replaced by server auth and the stored data
/// is discarded.
///
/// The demo account (AppStore.demoEmail) is checked separately by the
/// sign-in flow and is never written here.
class AuthStore {
  const AuthStore._();

  static const _kUsers = 'carepaws.auth.users';

  /// Email → {name, password, createdAt}.
  static Future<Map<String, Map<String, String>>> _readUsers() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kUsers);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeUsers(
    Map<String, Map<String, String>> users,
  ) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kUsers, jsonEncode(users));
    } catch (_) {
      // Storage failure: the in-memory flow still works for this session.
    }
  }

  static String _norm(String email) => email.trim().toLowerCase();

  /// True when the email is already registered.
  static Future<bool> exists(String email) async {
    final users = await _readUsers();
    return users.containsKey(_norm(email));
  }

  /// Validates and stores a new account. Returns null on success, or a
  /// user-facing error message.
  static Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = _norm(email);

    if (cleanName.isEmpty) return 'Please enter your name.';
    if (!_looksLikeEmail(cleanEmail)) {
      return 'That email address does not look right.';
    }
    final pwError = validatePassword(password);
    if (pwError != null) return pwError;

    final users = await _readUsers();
    if (users.containsKey(cleanEmail)) {
      return 'An account with that email already exists. Try signing in.';
    }

    users[cleanEmail] = {
      'name': cleanName,
      'password': password,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await _writeUsers(users);
    return null;
  }

  /// Returns the registered display name when the email + password match,
  /// null otherwise.
  static Future<String?> authenticate(String email, String password) async {
    final users = await _readUsers();
    final entry = users[_norm(email)];
    if (entry == null) return null;
    if (entry['password'] != password) return null;
    return entry['name'];
  }

  /// Display name for a registered email, without checking the password.
  /// Used to restore a saved session on boot — the session was already
  /// authenticated when it was persisted, so this must NOT re-authenticate.
  /// Returns null for unknown emails (and for the demo account, which is
  /// never stored here).
  static Future<String?> displayName(String email) async {
    final users = await _readUsers();
    return users[_norm(email)]?['name'];
  }

  /// Password rule, shared by the create-account form and [register]:
  /// at least 8 characters with at least one letter and one number.
  /// Returns null when the password is acceptable, otherwise the
  /// user-facing reason it is not.
  static String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Use at least 8 characters.';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    if (!hasLetter || !hasDigit) {
      return 'Use letters and numbers together.';
    }
    return null;
  }

  static bool _looksLikeEmail(String s) {
    if (s.isEmpty || s.length > 254) return false;
    final parts = s.split('@');
    if (parts.length != 2) return false;
    if (parts[0].isEmpty || parts[1].isEmpty) return false;
    if (!parts[1].contains('.')) return false;
    if (s.contains(' ')) return false;
    return true;
  }
}
