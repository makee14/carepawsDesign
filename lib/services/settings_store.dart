import 'package:shared_preferences/shared_preferences.dart';

import '../design/theme.dart' show ThemeMode;

/// Persists the handful of preferences that have to survive a relaunch.
///
/// Without this, Appearance → Dark flips the palette for one session and then
/// silently reverts, which reads as "dark mode is broken" rather than as a
/// setting. Everything here is a scalar, so [SharedPreferences] is plenty.
class SettingsStore {
  const SettingsStore._();

  static const _kThemeMode = 'carepaws.settings.themeMode';
  static const _kReduceMotion = 'carepaws.settings.reduceMotion';
  static const _kLanguage = 'carepaws.settings.language';
  static const _kOnboarded = 'carepaws.settings.onboarded';
  static const _kSessionEmail = 'carepaws.settings.sessionEmail';

  /// SharedPreferences throws in unit tests and on desktop without the plugin.
  /// A failure here must never stop the app from launching, so every call is
  /// wrapped and simply reports "nothing stored".
  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Reads the stored appearance choice. Returns null when nothing has been
  /// stored yet, which the caller treats as [ThemeMode.system].
  static Future<String?> readThemeMode() async {
    final p = await _prefs();
    return p?.getString(_kThemeMode);
  }

  static Future<void> writeThemeMode(ThemeMode mode) async {
    final p = await _prefs();
    await p?.setString(_kThemeMode, mode.name);
  }

  static Future<bool?> readReduceMotion() async {
    final p = await _prefs();
    return p?.getBool(_kReduceMotion);
  }

  static Future<void> writeReduceMotion(bool value) async {
    final p = await _prefs();
    await p?.setBool(_kReduceMotion, value);
  }

  static Future<String?> readLanguage() async {
    final p = await _prefs();
    return p?.getString(_kLanguage);
  }

  static Future<void> writeLanguage(String value) async {
    final p = await _prefs();
    await p?.setString(_kLanguage, value);
  }

  /// HIG ▸ Onboarding: the flow is shown once. Skipping counts as having seen
  /// it, so it is recorded exactly the same way as finishing it.
  static Future<bool> readOnboarded() async {
    final p = await _prefs();
    return p?.getBool(_kOnboarded) ?? false;
  }

  static Future<void> writeOnboarded(bool value) async {
    final p = await _prefs();
    await p?.setBool(_kOnboarded, value);
  }

  /// Email of the last successfully signed-in account, so the session
  /// survives the OS killing the app in the background. Cleared on sign-out.
  static Future<String?> readSessionEmail() async {
    final p = await _prefs();
    return p?.getString(_kSessionEmail);
  }

  static Future<void> writeSessionEmail(String email) async {
    final p = await _prefs();
    await p?.setString(_kSessionEmail, email);
  }

  static Future<void> clearSessionEmail() async {
    final p = await _prefs();
    await p?.remove(_kSessionEmail);
  }
}
