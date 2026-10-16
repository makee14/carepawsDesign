import 'package:shared_preferences/shared_preferences.dart';

/// Opens SharedPreferences, or null when the plugin is unavailable (unit
/// tests, desktop without the plugin). A null here must never stop the app —
/// every caller treats it as "nothing stored" and carries on in memory.
Future<SharedPreferences?> openPrefs() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (_) {
    return null;
  }
}
