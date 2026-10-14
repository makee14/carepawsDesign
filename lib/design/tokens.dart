import 'package:flutter/widgets.dart';

/// Locked PetCare design tokens. Sampled from the official logo + approved
/// palette. Contrast ratios were computed and are asserted in tests.
class T {
  const T._();

  // ---- locked brand palette -------------------------------------------------
  static const orange = Color(0xFFE4843E); // logo mark, illustration accents
  static const terracotta = Color(0xFFD4621A); // large text, icons, accents
  static const amber = Color(0xFFF4AE52); // chips, ratings (never carries text)
  static const espresso = Color(0xFF2A1A0E); // primary text, 15.27:1 on cream
  static const ink = Color(0xFF25221E); // wordmark ink, large titles
  static const cream = Color(0xFFFEF3E2); // app background
  static const card = Color(0xFFFFFFFF); // cards on cream
  static const taupe = Color(0xFF9B8A76); // secondary icons, dividers
  static const sand = Color(0xFFC7AB83); // decorative tint only
  static const destructive = Color(0xFFDC2626);

  // ---- derived semantic tokens (contrast-verified) --------------------------
  /// #2A1A0E — 15.27:1 on cream, 16.77:1 on card.
  static const text = Color(0xFF2A1A0E);
  /// #6B5646 — 6.28:1 on cream, 6.90:1 on card. Secondary copy stays readable.
  static const textSecondary = Color(0xFF6B5646);
  /// #A8480F — darkened terracotta, 5.32:1 on cream / 5.84:1 with white text.
  static const terracottaDeep = Color(0xFFA8480F);
  /// #B14E12 — readable terracotta for small secondary labels (4.82:1).
  static const terracottaText = Color(0xFFB14E12);

  // ---- spacing / radii / motion ---------------------------------------------
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  static const double rCard = 20;
  static const double rControl = 14;
  static const double rPill = 999;

  // ---- elevation: one language for every card --------------------------------
  // Every card floats at exactly this height; only the shadow colour adapts
  // to the theme (6% espresso on light; the palette's glass shadow on dark,
  // where SoftCard stays flat). GlassCard and SoftCard share these values so
  // two cards side by side never read as different elevations.
  static const double shadowBlur = 18;
  static const double shadowDy = 6;
  static const Color shadowLight = Color(0x0F2A1A0E);

  /// HIG minimum comfortable touch target.
  static const double tap = 48;

  static const double glassBlur = 14;
  static const int pressMs = 200;
  static const int springMs = 420;
}

/// Geometry that changes with device size / orientation.
class Layout {
  const Layout._();

  static bool landscape(BoxConstraints c) => c.maxWidth > c.maxHeight;

  /// Compressed hero heights in landscape so the CTA and tab bar stay reachable.
  static double heroHeight(BuildContext c, double portrait) {
    final size = MediaQuery.sizeOf(c);
    final wide = size.width > size.height;
    final huge = MediaQuery.textScalerOf(c).scale(1) > 1.35;
    if (wide) return portrait * 0.62;
    if (huge) return portrait * 1.12;
    return portrait;
  }

  /// Horizontal page gutter; tighter in landscape.
  static EdgeInsets gutter(BuildContext c) {
    final size = MediaQuery.sizeOf(c);
    return EdgeInsets.symmetric(horizontal: size.width > size.height ? 16 : 20);
  }

  static double scale(BuildContext c, double value) {
    final t = MediaQuery.textScalerOf(c).scale(13) / 13;
    return value * t.clamp(1.0, 1.6);
  }

  /// Keeps a fixed-height slot from clipping text at large Dynamic Type sizes —
  /// switches to intrinsic height so the page simply scrolls instead.
  static bool needsTallLayout(BuildContext c) =>
      MediaQuery.textScalerOf(c).scale(1) > 1.35;
}