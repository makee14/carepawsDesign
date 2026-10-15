import 'dart:math' show pow;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/design/tokens.dart';
import 'package:carepaws/screens/triage_screen.dart';
import 'package:carepaws/widgets/common.dart';

/// Second-pass contrast sweep (Worker D, 2026-10-15).
///
/// Unlike the token spot-checks in unit_test.dart, this walks every
/// text/icon-on-background pairing the UI actually renders — chips, pills,
/// buttons (incl. disabled), secondary text, scrims over photos, the tab bar,
/// section headers — in BOTH themes, compositing translucent colours over
/// their real backdrops before measuring. WCAG 2.1: >= 4.5:1 for small text,
/// >= 3:1 for large text (>= 18pt / 14pt bold) and icons.
///
/// Failures fixed in this pass (before -> after, measured):
/// - settings "Live" chip in dark mode: 1.48:1 -> 5.6+:1 (theme-aware bg)
/// - triage tones in dark mode: calm 1.85, mid 2.39, alert 1.89, info 1.52
///   -> dark twins at 6.24 / 4.95 / 5.26 / 6.88
/// - PrimaryButton disabled in light mode: 2.00:1 -> ghosted whole button,
///   keeping the verified enabled label/fill ratio.
void main() {
  double lum(Color c) {
    double f(double v) =>
        v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  }

  double ratio(Color a, Color b) {
    final l1 = lum(a), l2 = lum(b);
    final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Alpha-composite [fg] over an opaque [backdrop].
  Color over(Color fg, Color backdrop) {
    final a = fg.a;
    double mix(double f, double b) => f * a + b * (1 - a);
    return Color.from(
      alpha: 1,
      red: mix(fg.r, backdrop.r),
      green: mix(fg.g, backdrop.g),
      blue: mix(fg.b, backdrop.b),
    );
  }

  /// One measured pairing. Throws the test on failure with the real numbers.
  void check(String name, Color fg, Color bg, double min) {
    final r = ratio(fg, bg);
    expect(
      r,
      greaterThanOrEqualTo(min),
      reason:
          '$name: ${r.toStringAsFixed(2)}:1 < ${min.toStringAsFixed(1)}:1 '
          '(fg #${fg.toARGB32().toRadixString(16).padLeft(8, '0')}, '
          'bg #${bg.toARGB32().toRadixString(16).padLeft(8, '0')})',
    );
  }

  const light = AppPalette.light;
  const dark = AppPalette.dark;
  // 0xFFDDF2E3 — the hardcoded success-chip green used by several screens.
  const successChipLight = Color(0xFFDDF2E3);

  test('LIGHT — core text on every surface', () {
    for (final bg in [light.background, light.surface, light.surfaceAlt]) {
      check('text on surface', light.text, bg, 4.5);
      check('textSecondary on surface', light.textSecondary, bg, 4.5);
    }
    check('text on fieldBg', light.text, light.fieldBg, 4.5);
    check('textSecondary on fieldBg', light.textSecondary, light.fieldBg, 4.5);
    check('title on background', light.title, light.background, 3.0);
    check(
      'accent (icons/large) on background',
      light.accent,
      light.background,
      3.0,
    );
    for (final bg in [light.background, light.surface, light.fieldBg]) {
      check('accentText on surface', light.accentText, bg, 4.5);
    }
    check('primary button label', light.onPrimaryFill, light.primaryFill, 4.5);
    check('chip text', light.chipText, light.chipBg, 4.5);
    for (final bg in [light.background, light.surface]) {
      check('destructive on surface', light.destructive, bg, 4.5);
      check('success on surface', light.success, bg, 4.5);
    }
    check('success on success-chip', light.success, successChipLight, 4.5);
    check(
      'warning on amber chip',
      light.warning,
      over(T.amber.withValues(alpha: 0.28), light.surface),
      4.5,
    );
    check('espresso on amber countdown chip', T.espresso, T.amber, 4.5);
    check(
      'GlassPill cream on 60% black over white photo',
      T.cream,
      over(const Color(0xFF000000).withValues(alpha: 0.60), T.card),
      4.5,
    );
    check(
      'tab label (unselected taupe) on glass',
      T.taupe,
      over(light.glassTint, light.background),
      4.5,
    );
    check(
      'tab label (selected) on glass',
      light.primaryFill,
      over(light.glassTint, light.background),
      4.5,
    );
    check(
      'SecondaryButton label on fieldBg',
      light.accentText,
      light.fieldBg,
      4.5,
    );
    check(
      'EmptyState icon on amber circle',
      light.accent,
      over(T.amber.withValues(alpha: 0.22), light.surface),
      3.0,
    );
    check(
      'Photo attached chip: espresso on 90% cream over white photo',
      T.espresso,
      over(T.cream.withValues(alpha: 0.9), T.card),
      4.5,
    );
    check(
      'emergency card text on destructive fill',
      light.onPrimaryFill,
      light.destructive,
      4.5,
    );
  });

  test('DARK — core text on every surface', () {
    for (final bg in [dark.background, dark.surface, dark.surfaceAlt]) {
      check('text on surface', dark.text, bg, 4.5);
      check('textSecondary on surface', dark.textSecondary, bg, 4.5);
    }
    check('text on fieldBg', dark.text, dark.fieldBg, 4.5);
    check('textSecondary on fieldBg', dark.textSecondary, dark.fieldBg, 4.5);
    check('title on background', dark.title, dark.background, 3.0);
    check(
      'accent (icons/large) on background',
      dark.accent,
      dark.background,
      3.0,
    );
    for (final bg in [dark.background, dark.surface, dark.fieldBg]) {
      check('accentText on surface', dark.accentText, bg, 4.5);
    }
    check('primary button label', dark.onPrimaryFill, dark.primaryFill, 4.5);
    check('chip text', dark.chipText, dark.chipBg, 4.5);
    for (final bg in [dark.background, dark.surface]) {
      check('destructive on surface', dark.destructive, bg, 4.5);
      check('success on surface', dark.success, bg, 4.5);
    }
    check(
      'success on translucent success chip',
      dark.success,
      over(dark.success.withValues(alpha: 0.12), dark.surface),
      4.5,
    );
    for (final a in [0.28, 0.24, 0.16]) {
      check(
        'warning on amber@${(a * 100).round()}% chip',
        dark.warning,
        over(T.amber.withValues(alpha: a), dark.surface),
        4.5,
      );
    }
    check('espresso on amber countdown chip', T.espresso, T.amber, 4.5);
    check(
      'GlassPill cream on 60% black over white photo',
      T.cream,
      over(const Color(0xFF000000).withValues(alpha: 0.60), T.card),
      4.5,
    );
    check(
      'tab label (unselected sand) on glass',
      T.sand,
      over(dark.glassTint, dark.background),
      4.5,
    );
    check(
      'tab label (selected amber) on glass',
      dark.primaryFill,
      over(dark.glassTint, dark.background),
      4.5,
    );
    check(
      'SecondaryButton label on fieldBg',
      dark.accentText,
      dark.fieldBg,
      4.5,
    );
    check(
      'EmptyState icon on amber circle',
      dark.accent,
      over(T.amber.withValues(alpha: 0.22), dark.surface),
      3.0,
    );
    check(
      'photo remove scrim: white icon on 70% near-black over white photo',
      T.card,
      over(const Color(0xB21A1008), T.card),
      4.5,
    );
    check(
      'emergency card text on destructive fill',
      dark.onPrimaryFill,
      dark.destructive,
      4.5,
    );
  });

  test('appointment status chips — dark composites', () {
    // statusFg/statusBg in appointments_screen.dart.
    final pairs = <(String, Color, Color, double)>[
      (
        'confirmed',
        const Color(0xFF7FD3A0),
        over(const Color(0x1F7FD3A0), dark.surface),
        4.5,
      ),
      (
        'booked',
        T.amber,
        over(T.amber.withValues(alpha: 0.16), dark.surface),
        4.5,
      ),
      (
        'requestPending',
        const Color(0xFFFFC08A),
        over(T.orange.withValues(alpha: 0.18), dark.surface),
        4.5,
      ),
      (
        'cancelled',
        const Color(0xFFFF9A92),
        over(const Color(0x1FFF9A92), dark.surface),
        4.5,
      ),
    ];
    for (final (name, fg, bg, min) in pairs) {
      check('dark status chip $name', fg, bg, min);
    }
  });

  test('appointment status chips — light', () {
    final pairs = <(String, Color, Color)>[
      ('confirmed', const Color(0xFF1F5C33), const Color(0xFFDDF2E3)),
      ('booked', const Color(0xFF7A4A1B), const Color(0xFFFBEBD6)),
      ('requestPending', const Color(0xFF7A4A1B), const Color(0xFFFDE3C7)),
      ('readyForPickup', const Color(0xFF8A4A10), const Color(0xFFFDE3C7)),
      ('cancelled', const Color(0xFF9B1C1C), const Color(0xFFFDE2E2)),
    ];
    for (final (name, fg, bg) in pairs) {
      check('light status chip $name', fg, bg, 4.5);
    }
  });

  test('success icon circles (order success / appointment sheet)', () {
    // 12%-alpha light-green circle with p.success / p.warning icon.
    check(
      'light success icon',
      light.success,
      over(const Color(0x1FDDF2E3), light.surface),
      3.0,
    );
    check(
      'dark success icon',
      dark.success,
      over(const Color(0x1FDDF2E3), dark.surface),
      3.0,
    );
    check(
      'dark warning icon on 70% near-black scrim over photo',
      dark.warning,
      over(const Color(0xB21A1008), T.card),
      3.0,
    );
  });

  test('settings provider card Live chip — theme-aware bg', () {
    // _ProviderCard used to hardcode the light-green chip bg in both themes
    // (dark measured 1.48:1); now it follows the triage clinic-open pattern.
    check('light Live chip', light.success, successChipLight, 4.5);
    check(
      'dark Live chip',
      dark.success,
      over(dark.success.withValues(alpha: 0.12), dark.surface),
      4.5,
    );
  });

  test('orders cancelled chip (hardcoded 12% red bg, both themes)', () {
    check(
      'light cancelled chip',
      light.destructive,
      over(const Color(0x1FDC2626), light.surface),
      4.5,
    );
    check(
      'dark cancelled chip',
      dark.destructive,
      over(const Color(0x1FDC2626), dark.surface),
      4.5,
    );
  });

  test('triage tone pairings — light', () {
    final tones = <(String, Tone)>[
      ('calm', Tone.calm),
      ('mid', Tone.mid),
      ('alert', Tone.alert),
      ('info', Tone.info),
    ];
    for (final (name, tone) in tones) {
      final t = Tone.of(tone, false);
      final eff = over(t.bg, light.surface);
      check('light tone $name chip text', t.fg, eff, 4.5);
      check('light tone $name icon on circle', t.fg, eff, 3.0);
    }
  });

  test('triage tone pairings — dark uses the dark twins', () {
    // Before the fix these measured calm 1.85, mid 2.39, alert 1.89,
    // info 1.52. Tone.of routes to the dark twins now.
    final tones = <(String, Tone)>[
      ('calm', Tone.calm),
      ('mid', Tone.mid),
      ('alert', Tone.alert),
      ('info', Tone.info),
    ];
    for (final (name, tone) in tones) {
      final t = Tone.of(tone, true);
      final eff = over(t.bg, dark.surface);
      check('dark tone $name chip text', t.fg, eff, 4.5);
      check('dark tone $name icon on circle', t.fg, eff, 3.0);
    }
  });

  test('triage _NoteBox + AiUnavailableCard — dark', () {
    final noteBg = over(T.amber.withValues(alpha: 0.16), dark.background);
    check('note icon accentText', dark.accentText, noteBg, 4.5);
    check('note body textSecondary', dark.textSecondary, noteBg, 4.5);
    final aiBg = over(T.amber.withValues(alpha: 0.12), dark.surface);
    check('AI-unavailable icon warning', dark.warning, aiBg, 3.0);
    check('AI-unavailable body textSecondary', dark.textSecondary, aiBg, 4.5);
  });

  test('chat thread — offline banner + triage handoff card', () {
    // _OfflineBanner: warning caption + accentText icon on amber@16% over the
    // page background. Triage handoff SoftCard: accent icon on amber@14%.
    for (final theme in [light, dark]) {
      final bannerBg = over(T.amber.withValues(alpha: 0.16), theme.background);
      check('offline banner text', theme.warning, bannerBg, 4.5);
      check('offline banner icon', theme.accentText, bannerBg, 3.0);
      check(
        'handoff card icon',
        theme.accent,
        over(T.amber.withValues(alpha: 0.14), theme.background),
        3.0,
      );
    }
  });

  testWidgets('disabled PrimaryButton ghosts the whole button', (tester) async {
    // Regression: fading only the fill measured 2.0:1 in light mode. The
    // button must ghost (opacity < 1) instead, keeping the verified
    // label/fill ratio; enabled buttons stay at full opacity.
    for (final palette in [AppPalette.light, AppPalette.dark]) {
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(palette),
          home: const CupertinoPageScaffold(
            child: Center(child: PrimaryButton(label: 'Save', onPressed: null)),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1.0));

      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(palette),
          home: CupertinoPageScaffold(
            child: Center(
              child: PrimaryButton(label: 'Save', onPressed: () {}),
            ),
          ),
        ),
      );
      final opacityOn = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityOn.opacity, 1.0);
    }
  });
}
