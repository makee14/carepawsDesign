
import '../services/prefs.dart';

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

  /// Returns the stored name/phone for [email]; missing values come back ''.
  static Future<({String name, String phone})> read(String email) async {
    final p = await openPrefs();
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
    final p = await openPrefs();
    await p?.setString(_key(email, 'name'), name);
    await p?.setString(_key(email, 'phone'), phone);
  }
}
