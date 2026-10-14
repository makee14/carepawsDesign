import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores owner-chosen photos on the device.
///
/// Photos are kept as base64 JPEG in [SharedPreferences]. That is deliberately
/// simple rather than ideal: it is fine for a handful of small, heavily
/// downscaled portraits, and it needs no extra plugin or filesystem work. A
/// shipping app would write to app storage and keep a file path instead.
class PhotoStore {
  const PhotoStore._();

  static const ownerKey = 'carepaws.photo.owner';

  /// Picks and downsizes a photo. Returns null when the picker is unavailable
  /// (desktop, or a simulator with no library) or the user cancels.
  static Future<Uint8List?> pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Avatars are displayed small; this keeps a portrait in the tens of
        // kilobytes so a handful of them stay cheap to store.
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 72,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      // No camera / gallery here. Never a dead end: the UI keeps whatever
      // portrait it already had.
      return null;
    }
  }

  static String petKey(String petId) => 'carepaws.photo.pet.$petId';

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      // Unit tests and desktop without the plugin: treat as "nothing stored".
      return null;
    }
  }

  static Future<void> save(String key, Uint8List bytes) async {
    final p = await _prefs();
    await p?.setString(key, base64Encode(bytes));
  }

  static Future<void> remove(String key) async {
    final p = await _prefs();
    await p?.remove(key);
  }

  static Future<Uint8List?> load(String key) async {
    final p = await _prefs();
    final raw = p?.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      // Corrupt entry (truncated write, schema change) — drop it rather than
      // crash the profile on every launch.
      await p?.remove(key);
      return null;
    }
  }
}
