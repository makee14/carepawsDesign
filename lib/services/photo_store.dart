import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'prefs.dart';

/// Stores owner-chosen photos on the device.
///
/// Photos are kept as base64 JPEG in [SharedPreferences]. That is deliberately
/// simple rather than ideal: it is fine for a handful of portraits, and it
/// needs no extra plugin or filesystem work. A shipping app would write to
/// app storage and keep a file path instead.
///
/// ponytail: 1600px/q85 is the ceiling this store can carry — a 1600px JPEG
/// at q85 is ~200-400KB base64'd, so a dozen photos stay under a few MB of
/// prefs. If photo counts or sizes grow past what prefs comfortably holds
/// (slow launch, write failures), move to file storage via path_provider
/// (not currently a dependency) and keep only paths here. Do not raise the
/// caps without making that move first.
class PhotoStore {
  const PhotoStore._();

  /// Longest edge, in px, that [pick] keeps. Covers 3x full-bleed rendering
  /// at 390pt wide (1170px) with headroom; see the ponytail note above.
  static const maxEdge = 1600;

  /// JPEG quality for [pick]. 85 is visually lossless for pet portraits at
  /// these sizes; below 80 the fur detail visibly smears.
  static const jpegQuality = 85;

  static const ownerKey = 'carepaws.photo.owner';

  /// Picks a photo at proper resolution. Returns null when the picker is
  /// unavailable (desktop, or a simulator with no library) or the user
  /// cancels.
  ///
  /// The old 640px/q72 caps downscaled portraits into mush and then let the
  /// UI upscale them back — that was the photo-quality bug. Photos are now
  /// kept at up to [maxEdge] so every render site has real pixels to work
  /// with; downscaling happens at render time via [memoryImage], never in
  /// storage.
  static Future<Uint8List?> pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: maxEdge.toDouble(),
        maxHeight: maxEdge.toDouble(),
        imageQuality: jpegQuality,
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

  /// Builds an [Image] decoded at no more than [displayWidthPt] × the device
  /// pixel ratio, capped at [maxEdge] — the store never keeps more than that,
  /// so decoding larger is pure waste.
  ///
  /// Pass the width the layout actually gives the image, not the width you
  /// wish it had: the layout box bounds what is painted, so a smaller
  /// source is never upscaled on screen.
  static Widget memoryImage(
    BuildContext context,
    Uint8List bytes, {
    required double displayWidthPt,
    BoxFit fit = BoxFit.cover,
    String? semanticLabel,
  }) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (displayWidthPt * dpr).round().clamp(1, maxEdge);
    return Image.memory(
      bytes,
      cacheWidth: cacheWidth,
      fit: fit,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  static String petKey(String petId) => 'carepaws.photo.pet.$petId';

  static Future<void> save(String key, Uint8List bytes) async {
    final p = await openPrefs();
    await p?.setString(key, base64Encode(bytes));
  }

  static Future<void> remove(String key) async {
    final p = await openPrefs();
    await p?.remove(key);
  }

  static Future<Uint8List?> load(String key) async {
    final p = await openPrefs();
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
