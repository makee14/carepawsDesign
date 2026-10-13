import 'package:flutter/cupertino.dart';

import 'tokens.dart';

/// Semantic colour set. Two instances exist: [AppPalette.light] (the default,
/// per the brief — dark mode is never the default) and [AppPalette.dark],
/// the HIG §7 matching secondary theme.
@immutable
class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.textSecondary,
    required this.title,
    required this.accent,
    required this.accentText,
    required this.primaryFill,
    required this.onPrimaryFill,
    required this.chipBg,
    required this.chipText,
    required this.divider,
    required this.destructive,
    required this.success,
    required this.warning,
    required this.glassTint,
    required this.glassBorder,
    required this.glassShadow,
    required this.fieldBg,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color textSecondary;
  final Color title;
  final Color accent; // terracotta family: icons, large text, accents
  final Color accentText; // accent tone that is safe for small text
  final Color primaryFill;
  final Color onPrimaryFill;
  final Color chipBg;
  final Color chipText;
  final Color divider;
  final Color destructive;
  final Color success;
  final Color warning;
  final Color glassTint;
  final Color glassBorder;
  final Color glassShadow;
  final Color fieldBg;
  final bool isDark;

  static const light = AppPalette(
    background: T.cream,
    surface: T.card,
    surfaceAlt: Color(0xFFFDF9F1),
    text: T.espresso,
    textSecondary: T.textSecondary,
    title: T.ink,
    accent: T.terracotta,
    accentText: T.terracottaText,
    primaryFill: T.terracottaDeep,
    onPrimaryFill: T.card,
    chipBg: Color(0xFFFBEBD6),
    chipText: Color(0xFF7A4A1B),
    divider: Color(0x14000000),
    destructive: T.destructive,
    success: Color(0xFF1F5C33),
    warning: Color(0xFF7A4A1B),
    glassTint: Color(0xCCFFFFFF),
    glassBorder: Color(0x59FFFFFF),
    glassShadow: Color(0x1F2A1A0E),
    fieldBg: Color(0xFFF7F0E4),
    isDark: false,
  );

  static const dark = AppPalette(
    background: Color(0xFF191210),
    surface: Color(0xFF241B17),
    surfaceAlt: Color(0xFF2C211C),
    text: Color(0xFFF6E7D6),
    textSecondary: Color(0xFFD9C4B0),
    title: Color(0xFFFEF3E2),
    accent: Color(0xFFF08A5D),
    accentText: Color(0xFFF4AE52),
    primaryFill: Color(0xFFF4AE52),
    onPrimaryFill: Color(0xFF2A1A0E),
    chipBg: Color(0xFF3A2A21),
    chipText: Color(0xFFF6E7D6),
    divider: Color(0x1FFFFFFF),
    destructive: Color(0xFFFF8A80),
    success: Color(0xFF7BD88F),
    warning: Color(0xFFF4AE52),
    glassTint: Color(0xD9261D18),
    glassBorder: Color(0x33FFFFFF),
    glassShadow: Color(0x66000000),
    fieldBg: Color(0xFF2C211C),
    isDark: true,
  );

  /// Amber is an accent surface only — text on it is always espresso.
  static const onAccent = T.espresso;
}

extension PaletteX on BuildContext {
  AppPalette get p =>
      CupertinoTheme.of(this).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
}

/// Appearance preference. Mirrors the three options in iOS Settings ▸
/// Appearance, and defaults to [ThemeMode.system] for the same reason iOS
/// does: the app should follow the device unless told otherwise.
///
/// Declared here rather than reusing Material's `ThemeMode`, which this
/// Cupertino-only app deliberately does not import.
enum ThemeMode {
  /// Follow the OS appearance.
  system,

  /// Always the warm light palette.
  light,

  /// Always the matching dark palette.
  dark;

  static ThemeMode fromName(String? name) => switch (name) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  /// Human label for the Appearance picker.
  String get label => switch (this) {
    ThemeMode.system => 'Automatic',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

CupertinoThemeData themeFor(AppPalette p) {
  TextStyle t(double size, FontWeight w, {double? h, Color? c, double? ls}) =>
      TextStyle(
        fontSize: size,
        fontWeight: w,
        height: h,
        letterSpacing: ls,
        color: c ?? p.text,
      );

  return CupertinoThemeData(
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    primaryColor: p.accent,
    primaryContrastingColor: p.isDark ? Color(0xFF191210) : T.card,
    scaffoldBackgroundColor: p.background,
    barBackgroundColor: p.background.withValues(alpha: p.isDark ? 0.86 : 0.82),
    applyThemeToAll: true,
    textTheme: CupertinoTextThemeData(
      primaryColor: p.accent,
      textStyle: t(17, FontWeight.w400),
      actionTextStyle: t(17, FontWeight.w600, c: p.accentText),
      navTitleTextStyle: t(17, FontWeight.w600),
      navLargeTitleTextStyle: t(34, FontWeight.w700, c: p.title, ls: -0.6),
      tabLabelTextStyle: t(10, FontWeight.w600),
      navActionTextStyle: t(17, FontWeight.w400, c: p.accentText),
      pickerTextStyle: t(20, FontWeight.w400),
      dateTimePickerTextStyle: t(20, FontWeight.w400),
    ),
  );
}

/// Type ramp: Large Title 34 semibold, Title 28, Headline 17 semibold,
/// Body 17, Footnote 13, Caption 12.
class Type {
  const Type._();
  static TextStyle largeTitle(AppPalette p) =>
      TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: p.title, letterSpacing: -0.6, height: 1.12);
  static TextStyle title1(AppPalette p) =>
      TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: p.title, letterSpacing: -0.4, height: 1.16);
  static TextStyle title2(AppPalette p) =>
      TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.title, height: 1.2);
  static TextStyle headline(AppPalette p) =>
      TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.text, height: 1.28);
  static TextStyle body(AppPalette p) =>
      TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: p.text, height: 1.42);
  static TextStyle callout(AppPalette p) =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.text, height: 1.35);
  static TextStyle footnote(AppPalette p) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: p.textSecondary, height: 1.35);
  static TextStyle footnoteEmph(AppPalette p) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text, height: 1.35);
  static TextStyle caption(AppPalette p) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.textSecondary, height: 1.3);
  static TextStyle captionEmph(AppPalette p) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.textSecondary, height: 1.3);
  static TextStyle button(AppPalette p) =>
      TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.onPrimaryFill, height: 1.2);
}