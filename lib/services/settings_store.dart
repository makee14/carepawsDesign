
import 'prefs.dart';

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
  static const _kOnboardingCompleted = 'carepaws.onboarding.completed';
  static const _kSessionEmail = 'carepaws.settings.sessionEmail';

  /// Reads the stored appearance choice. Returns null when nothing has been
  /// stored yet, which the caller treats as [ThemeMode.system].
  static Future<String?> readThemeMode() async {
    final p = await openPrefs();
    return p?.getString(_kThemeMode);
  }

  static Future<void> writeThemeMode(ThemeMode mode) async {
    final p = await openPrefs();
    await p?.setString(_kThemeMode, mode.name);
  }

  static Future<bool?> readReduceMotion() async {
    final p = await openPrefs();
    return p?.getBool(_kReduceMotion);
  }

  static Future<void> writeReduceMotion(bool value) async {
    final p = await openPrefs();
    await p?.setBool(_kReduceMotion, value);
  }

  static Future<String?> readLanguage() async {
    final p = await openPrefs();
    return p?.getString(_kLanguage);
  }

  static Future<void> writeLanguage(String value) async {
    final p = await openPrefs();
    await p?.setString(_kLanguage, value);
  }

  /// HIG ▸ Onboarding: the flow is shown once. Skipping counts as having seen
  /// it, so it is recorded exactly the same way as finishing it.
  ///
  /// LEGACY — kept only for the one-time migration in [readOnboardingCompleted].
  /// New code must use [readOnboardingCompleted]/[writeOnboardingCompleted].
  static Future<bool> readOnboarded() async {
    final p = await openPrefs();
    return p?.getBool(_kOnboarded) ?? false;
  }

  /// Whether the first-launch flow (splash → onboarding → register → Home)
  /// has completed. Null when never set. The single source of truth for
  /// launch routing; a completed flow never repeats.
  static Future<bool?> readOnboardingCompleted() async {
    final p = await openPrefs();
    return p?.getBool(_kOnboardingCompleted);
  }

  static Future<void> writeOnboardingCompleted(bool value) async {
    final p = await openPrefs();
    await p?.setBool(_kOnboardingCompleted, value);
  }

  /// Email of the last successfully signed-in account, so the session
  /// survives the OS killing the app in the background. Cleared on sign-out.
  static Future<String?> readSessionEmail() async {
    final p = await openPrefs();
    return p?.getString(_kSessionEmail);
  }

  static Future<void> writeSessionEmail(String email) async {
    final p = await openPrefs();
    await p?.setString(_kSessionEmail, email);
  }

  static Future<void> clearSessionEmail() async {
    final p = await openPrefs();
    await p?.remove(_kSessionEmail);
  }
}
