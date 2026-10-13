import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tokens.dart';

/// Hand-authored SF-Symbol-style **line** icons. Every icon in the app is an
/// SVG line glyph — emoji are never used as icons.
///
/// All paths are authored on a 24x24 grid and rendered as strokes.
class Ic {
  const Ic._();

  /// Stroke-rendered SVG line icon.
  static Widget svg(
    String d, {
    required Color color,
    double size = 24,
    double stroke = 1.8,
  }) => SvgPicture.string(
    '<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="$d" stroke="${_hex(color)}" stroke-width="$stroke" '
    'stroke-linecap="round" stroke-linejoin="round"/></svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    semanticsLabel: null,
  );

  static String _hex(Color c) =>
      '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
      '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
      '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';

  // ---------------------------------------------------------------- tabs
  static const home = 'M3.2 10.6 12 3.4l8.8 7.2M5.6 9v10.2a1.4 1.4 0 0 0 1.4 1.4h10a1.4 1.4 0 0 0 1.4-1.4V9M9.6 20.6v-6.2h4.8v6.2';
  static const chat = 'M4 6.2a2.2 2.2 0 0 1 2.2-2.2h11.6A2.2 2.2 0 0 1 20 6.2v7.6a2.2 2.2 0 0 1-2.2 2.2H9.4L5.6 19.2v-3.2H6.2A2.2 2.2 0 0 1 4 13.8z';
  static const calendar = 'M4.2 7.6a2 2 0 0 1 2-2h11.6a2 2 0 0 1 2 2v10.8a2 2 0 0 1-2 2H6.2a2 2 0 0 1-2-2zM4.2 10.2h15.6M8.4 4.2v2.8M15.6 4.2v2.8';
  static const bag = 'M4.6 8.2h14.8l-1.2 11.2a1.6 1.6 0 0 1-1.6 1.4H7.4a1.6 1.6 0 0 1-1.6-1.4zM8.8 9.6V7a3.2 3.2 0 0 1 6.4 0v2.6';
  static const person = 'M12 12.2a3.9 3.9 0 1 0 0-7.8 3.9 3.9 0 0 0 0 7.8ZM4.9 20.2c.7-3.7 3.5-5.7 7.1-5.7s6.4 2 7.1 5.7';

  // ------------------------------------------------------------- glyphs
  static const search = 'M11 18.2a7.2 7.2 0 1 0 0-14.4 7.2 7.2 0 0 0 0 14.4ZM16.4 16.4 20.6 20.6';
  static const bell = 'M18.2 10.6c0-3.6-2.4-6.2-5.4-6.6V3a.8.8 0 0 0-1.6 0v1c-3 .4-5.4 3-5.4 6.6 0 4.2-1.6 5.4-1.6 5.4h15.6s-1.6-1.2-1.6-5.4ZM10.1 19a2 2 0 0 0 3.8 0';
  static const chevronRight = 'M9.2 5.6 15.6 12l-6.4 6.4';
  static const chevronLeft = 'M14.8 5.6 8.4 12l6.4 6.4';
  static const chevronDown = 'M5.6 9.2 12 15.6l6.4-6.4';
  static const close = 'M6.2 6.2 17.8 17.8M17.8 6.2 6.2 17.8';
  static const plus = 'M12 5.2v13.6M5.2 12h13.6';
  static const minus = 'M5.2 12h13.6';
  static const check = 'M5 12.6 9.8 17.4 19 7.2';
  static const checkCircle = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM8.2 12.2 11 15l4.8-5.4';
  static const heart = 'M12 20.1s-7.7-4.5-7.7-9.5a4.3 4.3 0 0 1 7.7-2.6 4.3 4.3 0 0 1 7.7 2.6c0 5-7.7 9.5-7.7 9.5Z';
  static const star = 'M12 3.6l2.6 5.3 5.8.8-4.2 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z';
  static const phone = 'M8.4 4.2 6.2 4a1.6 1.6 0 0 0-1.9 1.7c.5 5.9 5.5 11 11.4 11.5a1.6 1.6 0 0 0 1.7-1.9l-.3-2.3-3.9-1.3-2 2.1a13.6 13.6 0 0 1-5.1-5.1l2.1-2z';
  static const clock = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 7.2V12l3.2 1.9';
  static const pin = 'M12 21s6.2-5.6 6.2-10.2a6.2 6.2 0 1 0-12.4 0C5.8 15.4 12 21 12 21ZM12 13.1a2.4 2.4 0 1 0 0-4.8 2.4 2.4 0 0 0 0 4.8Z';
  static const doc = 'M13.4 3.6H7.2a1.8 1.8 0 0 0-1.8 1.8v13.2a1.8 1.8 0 0 0 1.8 1.8h9.6a1.8 1.8 0 0 0 1.8-1.8V8.6zM13.4 3.6v5h5M8.8 13h6.4M8.8 16.4h4.4';
  static const cart = 'M3.4 4.6h2.2l2.4 9.8a1.6 1.6 0 0 0 1.6 1.2h7.6a1.6 1.6 0 0 0 1.6-1.2l1.4-6.4H6.2M9.4 19.4a1.2 1.2 0 1 0 0-2.4 1.2 1.2 0 0 0 0 2.4ZM16.6 19.4a1.2 1.2 0 1 0 0-2.4 1.2 1.2 0 0 0 0 2.4Z';
  static const camera = 'M4 10.6a2 2 0 0 1 2-2h1.7l1.2-2.2a1.4 1.4 0 0 1 1.2-.7h5.8a1.4 1.4 0 0 1 1.2.7l1.2 2.2H20a2 2 0 0 1 2 2v6.6a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2zM12 17.4a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4Z';
  static const truck = 'M2.8 6.6h10.4v9.6H2.8zM13.2 9.8h3.6l2.8 3v3.4h-6.4zM6.6 19a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6ZM16.8 19a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6Z';
  static const location2 = 'M12 21.2c4.4-4.6 6.6-8.2 6.6-11.2a6.6 6.6 0 1 0-13.2 0c0 3 2.2 6.6 6.6 11.2ZM12 12.4a2.6 2.6 0 1 0 0-5.2 2.6 2.6 0 0 0 0 5.2Z';
  static const bookmark = 'M6.4 4.6h11.2v16l-5.6-4-5.6 4z';
  static const stethoscope =
      'M6.2 3.4v5.2a4 4 0 0 0 8 0V3.4M4.6 3.4h2.6M13.2 3.4h2.6M10.2 12.6v2.6a4.4 4.4 0 0 0 8.8 0v-1.4';
  static const stethoscope2 =
      'M6.2 3.2v5.4a4 4 0 0 0 8 0V3.2M4.6 3.2h2.8M13.4 3.2h2.8M10.2 12.6v2.2a4.6 4.6 0 0 0 9.2 0v-1.6M19.4 11.2a1.8 1.8 0 1 0 0 3.6 1.8 1.8 0 0 0 0-3.6Z';
  static const image = 'M4 6.8a1.8 1.8 0 0 1 1.8-1.8h12.4A1.8 1.8 0 0 1 20 6.8v10.4a1.8 1.8 0 0 1-1.8 1.8H5.8A1.8 1.8 0 0 1 4 17.2zM8.4 10.6a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM4.4 16.4l4.8-4.2 4 3.6 2.8-2.2 4.2 3.6';
  static const shield = 'M12 21.2s7.2-3 7.2-8.6V6.2L12 3.2 4.8 6.2v6.4c0 5.6 7.2 8.6 7.2 8.6Z';
  static const heartPulse = 'M12 20.4s-7.6-4.4-7.6-9.4a4.2 4.2 0 0 1 7.6-2.5 4.2 4.2 0 0 1 7.6 2.5c0 5-7.6 9.4-7.6 9.4ZM4.8 13.2h3l1.4-2.6 1.8 4.4 1.6-3 1.2 1.2h5';
  static const pill = 'M8.6 4.2a3.6 3.6 0 0 1 5.1 0l6.1 6.1a3.6 3.6 0 1 1-5.1 5.1L8.6 9.3a3.6 3.6 0 0 1 0-5.1ZM6.6 6.2 17.8 17.4';
  static const scissors = 'M7.2 8.6a2.6 2.6 0 1 0 0-5.2 2.6 2.6 0 0 0 0 5.2ZM7.2 20.6a2.6 2.6 0 1 0 0-5.2 2.6 2.6 0 0 0 0 5.2ZM9.4 7.4 19.8 19M19.8 5 9.4 16.6';
  static const syringe = 'M15.6 4.2 19.8 8.4M17.6 2.8l3.6 3.6M14.4 5.6 4.8 15.2a1.6 1.6 0 0 0-.4.7l-.7 3.3 3.3-.7c.3-.1.5-.2.7-.4l9.6-9.6zM11.2 8.8l4 4';
  static const trash = 'M4.6 6.6h14.8M9.4 6.6V4.8a1.2 1.2 0 0 1 1.2-1.2h2.8a1.2 1.2 0 0 1 1.2 1.2v1.8M6.6 6.6l.9 12.6a1.6 1.6 0 0 0 1.6 1.5h5.8a1.6 1.6 0 0 0 1.6-1.5l.9-12.6M10.2 10.2v6.6M13.8 10.2v6.6';
  static const pencil = 'M4.2 20.4l1.1-4.4L16 5.3a1.9 1.9 0 0 1 2.7 0l.8.8a1.9 1.9 0 0 1 0 2.7L8.9 19.5zM14.2 7.1l3.5 3.5';
  static const info = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 11v5.6M12 7.6v.1';
  static const alert = 'M12 3.4 21.2 19.6H2.8zM12 9.6v4.2M12 17v.1';
  static const sparkle = 'M12 3.4l1.7 4.5 4.5 1.7-4.5 1.7L12 15.8l-1.7-4.5L5.8 9.6l4.5-1.7zM18.4 15.6l.8 2.1 2.1.8-2.1.8-.8 2.1-.8-2.1-2.1-.8 2.1-.8z';
  static const moon = 'M20.4 14.2A8.6 8.6 0 0 1 9.8 3.6a8.6 8.6 0 1 0 10.6 10.6Z';
  static const globe = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM3.2 12h17.6M12 3a13.6 13.6 0 0 1 0 18 13.6 13.6 0 0 1 0-18Z';
  static const lock = 'M6.6 10.6h10.8a1.6 1.6 0 0 1 1.6 1.6v7a1.6 1.6 0 0 1-1.6 1.6H6.6A1.6 1.6 0 0 1 5 19.2v-7a1.6 1.6 0 0 1 1.6-1.6ZM8.4 10.6V7.8a3.6 3.6 0 0 1 7.2 0v2.8';
  static const settings = 'M4.4 7.6h6.4M14.8 7.6h4.8M4.4 16.4h4.8M13.2 16.4h6.4M12.4 7.6a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM11.6 16.4a2 2 0 1 0 0 4 2 2 0 0 0 0-4Z';
  static const paw = 'M12 20.4c3.4 0 5.6-1.8 5.6-4.2 0-2.2-1.8-3.2-2.6-4.8-.7-1.4-1.2-3.4-3-3.4s-2.3 2-3 3.4c-.8 1.6-2.6 2.6-2.6 4.8 0 2.4 2.2 4.2 5.6 4.2ZM6.4 9.6a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8ZM17.6 9.6a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8ZM10.4 4.6a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8ZM13.6 4.6a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z';
  static const qr = 'M4.4 4.4h5.2v5.2H4.4zM14.4 4.4h5.2v5.2h-5.2zM4.4 14.4h5.2v5.2H4.4zM14.4 14.4h2.2v2.2h-2.2zM17.8 17.8h2.2v2.2h-2.2zM14.4 20h2.2M20 14.4v2.2';
  static const wallet = 'M4.2 8.4a1.8 1.8 0 0 1 1.8-1.8h11.4a1.8 1.8 0 0 1 1.8 1.8v8.4a1.8 1.8 0 0 1-1.8 1.8H6a1.8 1.8 0 0 1-1.8-1.8zM4.2 10.8h15M15.8 14.4h2.4';
  static const gift = 'M4.6 10.6h14.8v9.2H4.6zM3.6 7h16.8v3.6H3.6zM12 7v12.8M12 7H8.6a2 2 0 1 1 2-2c0 1.2 1.4 2 1.4 2ZM12 7h3.4a2 2 0 1 0-2-2c0 1.2-1.4 2-1.4 2Z';
  static const barcode = 'M4.4 5.4v13.2M7.6 5.4v13.2M11 5.4v13.2M13.4 5.4v13.2M16.6 5.4v13.2M19.6 5.4v13.2M3 8.6h1.2M3 11h1.2M3 13.4h1.2M3 15.8h1.2';
  static const droplet = 'M12 3.4c3.4 4 5.4 6.8 5.4 9.4a5.4 5.4 0 1 1-10.8 0c0-2.6 2-5.4 5.4-9.4Z';
  static const sun = 'M12 16.6a4.6 4.6 0 1 0 0-9.2 4.6 4.6 0 0 0 0 9.2ZM12 2.6v2.2M12 19.2v2.2M2.6 12h2.2M19.2 12h2.2M5.4 5.4l1.6 1.6M17 17l1.6 1.6M18.6 5.4 17 7M7 17l-1.6 1.6';
  static const monitor = 'M3.4 5.4a1.8 1.8 0 0 1 1.8-1.8h13.6a1.8 1.8 0 0 1 1.8 1.8v9.6a1.8 1.8 0 0 1-1.8 1.8H5.2a1.8 1.8 0 0 1-1.8-1.8zM8.6 19h6.8M12 14.9v4.1';
  static const refresh = 'M20 12a8 8 0 1 1-2.6-5.9M20.2 4.2v4.4h-4.4';
  static const download = 'M12 3.8v11.4M7.6 11l4.4 4.4 4.4-4.4M4.6 19.8h14.8';
  static const upload = 'M12 15.6V4.2M7.6 8.6 12 4.2l4.4 4.4M4.6 19.8h14.8';
  static const send = 'M20.4 4.2 3.6 11l6.2 2.6 2.6 6.2zM9.8 13.6l10.6-9.4';
  static const filter = 'M3.6 5.4h16.8l-6.6 7.8v6L9.6 17.6v-4.4z';
  static const scale = 'M12 4.2a1.8 1.8 0 1 0 0 3.6 1.8 1.8 0 0 0 0-3.6ZM5.6 7.8h12.8l1.8 11.4a1 1 0 0 1-1 1.2H4.8a1 1 0 0 1-1-1.2z';
  static const tooth = 'M12 5.4c-1.4-1.6-3.2-2.4-5-2.4-2.6 0-3.6 2.4-3.2 5.4.4 3 1.2 4.6 1.8 7 .4 1.6.6 3.2 1.6 3.6 1.2.4 1.4-1.2 1.6-2.8.4-2 .6-4.4 3.2-4.4s2.8 2.4 3.2 4.4c.2 1.6.4 3.2 1.6 2.8 1-.4 1.2-2 1.6-3.6.6-2.4 1.4-4 1.8-7 .4-3-.6-5.4-3.2-5.4-1.8 0-3.6.8-5 2.4Z';
  static const clipboard = 'M9.4 4.6H7.2a1.8 1.8 0 0 0-1.8 1.8v13a1.8 1.8 0 0 0 1.8 1.8h9.6a1.8 1.8 0 0 0 1.8-1.8v-13a1.8 1.8 0 0 0-1.8-1.8h-2.2M9.4 2.8h5.2a.8.8 0 0 1 .8.8v2a.8.8 0 0 1-.8.8H9.4a.8.8 0 0 1-.8-.8v-2a.8.8 0 0 1 .8-.8Z';
  static const logout = 'M9.4 20.2H5.8a1.8 1.8 0 0 1-1.8-1.8V5.6a1.8 1.8 0 0 1 1.8-1.8h3.6M15.6 16.2l4.4-4.2-4.4-4.2M20 12H9.2';
  static const language = 'M3.4 5.6h8.2M7.5 3.4v2.2M5 13.6c1.4-3.2 3.8-5.4 6.8-6.6M4.6 16.8c3.8-.4 7-2.4 9-6M13.4 21.2l4-10.8 4 10.8M15 18h5';
  static const plusCircle = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 8.4v7.2M8.4 12h7.2';
  static const arrowRight = 'M4 12h16M13.6 5.6 20 12l-6.4 6.4';
  static const arrowUp = 'M12 20V4M5.6 10.4 12 4l6.4 6.4';
  static const card2 = 'M4.4 6.6h15.2a1.8 1.8 0 0 1 1.8 1.8v7.2a1.8 1.8 0 0 1-1.8 1.8H4.4a1.8 1.8 0 0 1-1.8-1.8V8.4a1.8 1.8 0 0 1 1.8-1.8ZM2.6 10.4h18.8M6.2 14.4h3.6';
  static const cash = 'M2.8 7.2h18.4a1 1 0 0 1 1 1v7.6a1 1 0 0 1-1 1H2.8a1 1 0 0 1-1-1V8.2a1 1 0 0 1 1-1ZM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM6 9.4v5.2M18 9.4v5.2';
  static const cat = 'M5.2 9.4 4 4.6l4.6 2.8M18.8 9.4 20 4.6l-4.6 2.8'
      'M12 5.2c-4.6 0-7.6 3.2-7.6 7.4 0 4 3.2 7 7.6 7s7.6-3 7.6-7c0-4.2-3-7.4-7.6-7.4Z'
      'M9.3 11.6v1.3M14.7 11.6v1.3M11.1 14.7h1.8M12 14.7v1.1'
      'M5.8 15.6l3 .5M18.2 15.6l-3 .5';
  static const dog = 'M7.4 5.2C4.6 5.9 3.6 8.4 4 11.4c.3 2.2 1.2 3.2 1.9 2.4'
      'M16.6 5.2c2.8.7 3.8 3.2 3.4 6.2-.3 2.2-1.2 3.2-1.9 2.4'
      'M12 4.8c-4.3 0-7.4 3.1-7.4 7.6 0 4.6 3.3 7.4 7.4 7.4s7.4-2.8 7.4-7.4c0-4.5-3.1-7.6-7.4-7.6Z'
      'M9.3 10.9v1.3M14.7 10.9v1.3M12 13.2v1.5'
      'M10.1 16.6c.5 1.1 1.1 1.6 1.9 1.6s1.4-.5 1.9-1.6';
  static const bone = 'M6.8 17.4a2.2 2.2 0 0 1 0-4.4 2.2 2.2 0 0 1 0-4.4 2.2 2.2 0 0 1 4.4 0l4 4a2.2 2.2 0 0 1 0 4.4 2.2 2.2 0 0 1-4.4 0z';
  static const eye = 'M2.8 12S6.4 6.4 12 6.4 21.2 12 21.2 12 17.6 17.6 12 17.6 2.8 12 2.8 12ZM12 14.8a2.8 2.8 0 1 0 0-5.6 2.8 2.8 0 0 0 0 5.6Z';
  static const fire = 'M12 20.8c3.4 0 6-2.4 6-5.6 0-4.4-4.2-5.6-3.6-10.4-2.6.8-4.2 3-4.2 5.4 0 1.4.6 2 .6 2s-1.8.6-2.4-1c-.8-2.2-.4-3.8.2-5.2C6 8 6 11.6 6 15.2c0 3.2 2.6 5.6 6 5.6Z';
}

/// 48x48 icon-only button with VoiceOver label, focus ring and press feedback.
class IconTap extends StatelessWidget {
  const IconTap({
    super.key,
    required this.path,
    required this.label,
    required this.onPressed,
    this.size = 24,
    this.color,
    this.background,
    this.badge = 0,
    this.disabled = false,
  });

  final String path;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? background;
  final int badge;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final palette = CupertinoTheme.of(context).primaryColor;
    final enabled = onPressed != null && !disabled;
    final c = disabled ? CupertinoColors.systemGrey : (color ?? palette);
    Widget core = Ic.svg(
      path,
      color: c,
      size: size,
      stroke: background != null ? 1.9 : 1.8,
    );
    if (background != null) {
      core = DecoratedBox(
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Padding(padding: const EdgeInsets.all(11), child: core),
      );
    }
    final btn = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: enabled ? onPressed : null,
          child: tapTarget(
            SizedBox.square(dimension: T.tap, child: Center(child: core)),
          ),
        ),
      ),
    );
    if (badge <= 0) return btn;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        btn,
        Positioned(
          right: 2,
          top: 2,
          child: Semantics(
            label: '$badge unread',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Wraps icon-only controls so they keep a 48pt touch target even when the
  /// surrounding chrome (navigation bars, tight rows) offers less.
  static Widget tapTarget(Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: T.tap, minHeight: T.tap),
    child: child,
  );
}

/// 200ms ease-out press scale (honored when Reduce Motion is on: it becomes a
/// plain opacity-free instant tap with no scaling).
///
/// Also the app's single keyboard-accessibility choke point: every control
/// routes through here, so each one is focusable, activates on Enter/Space, and
/// paints a 2pt Terracotta focus ring when focused. Traversal order follows the
/// widget tree, so it is the visual reading order and there are no traps.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final interactive = widget.onTap != null;

    Widget content = AnimatedScale(
      scale: (!reduce && _down) ? widget.scale : 1,
      duration: reduce ? Duration.zero : const Duration(milliseconds: T.pressMs),
      curve: Curves.easeOut,
      child: widget.child,
    );

    if (_focused && interactive) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: T.terracottaDeep, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!interactive) return content;

    return Focus(
      canRequestFocus: true,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          widget.onTap!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}