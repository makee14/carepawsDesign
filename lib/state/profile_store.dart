import 'package:shared_preferences/shared_preferences.dart';

/// Which editable owner-profile field a validation error belongs to.
enum ProfileField { name, phone }

/// Persists the editable owner profile (display name + phone) per account.
///
/// The account email is the sign-in key — it lives in [AuthStore]/[AppStore]
/// and is never edited here. Only the human-editable bits live in this store,
/// keyed by that email so two accounts on one device never share a profile.
class ProfileStore {
  const ProfileStore._();

  static String _key(String email, String field) =>
      'carepaws.profile.$email.$field';

  /// SharedPreferences throws in unit tests and on desktop without the plugin.
  /// A failure here must never stop the app, so every call is wrapped and
  /// simply reports "nothing stored".
  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Returns the stored name/phone for [email]; missing values come back ''.
  static Future<({String name, String phone})> read(String email) async {
    final p = await _prefs();
    if (p == null) return (name: '', phone: '');
    return (
      name: p.getString(_key(email, 'name')) ?? '',
      phone: p.getString(_key(email, 'phone')) ?? '',
    );
  }

  /// Overwrites the stored profile for [email].
  static Future<void> write({
    required String email,
    required String name,
    required String phone,
  }) async {
    final p = await _prefs();
    await p?.setString(_key(email, 'name'), name);
    await p?.setString(_key(email, 'phone'), phone);
  }
}
