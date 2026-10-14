import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tokens.dart';

/// Hand-authored SF-Symbol-style **line** icons. Every icon in the app is an
/// SVG line glyph — emoji are never used as icons.
///
/// All paths are authored on a 24x24 grid and rendered as strokes.
///
/// Family rules (Phase 5 redraw):
/// - 2px clear space: glyph bboxes sit inside 3..21, accents may reach 2.
/// - One corner language: rects use r=2, badge circles are r=9 at (12,12),
///   small circles use the two-arc full-circle form.
/// - Round caps/joins are set by [svg]; corners in path data rely on them.
/// - 1-decimal precision; details simplified so 16pt sizes stay legible.
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

  /// Resolves a seed icon *name* (e.g. `'sparkle'`) to its path data.
  ///
  /// Seed models ([Seed.services], vitals, reminders, threads) store icon
  /// names, not paths — call sites must go through this so the glyph actually
  /// renders. Unknown names fall back to [info], never to a blank glyph.
  static String byName(String name) {
    switch (name) {
      case 'home':
        return home;
      case 'chat':
        return chat;
      case 'calendar':
        return calendar;
      case 'bag':
        return bag;
      case 'person':
        return person;
      case 'search':
        return search;
      case 'bell':
        return bell;
      case 'chevronRight':
        return chevronRight;
      case 'chevronLeft':
        return chevronLeft;
      case 'chevronDown':
        return chevronDown;
      case 'close':
        return close;
      case 'plus':
        return plus;
      case 'minus':
        return minus;
      case 'check':
        return check;
      case 'checkCircle':
        return checkCircle;
      case 'heart':
        return heart;
      case 'star':
        return star;
      case 'phone':
        return phone;
      case 'clock':
        return clock;
      case 'pin':
        return pin;
      case 'doc':
        return doc;
      case 'cart':
        return cart;
      case 'camera':
        return camera;
      case 'truck':
        return truck;
      case 'bookmark':
        return bookmark;
      case 'stethoscope':
        return stethoscope;
      case 'image':
        return image;
      case 'shield':
        return shield;
      case 'heartPulse':
        return heartPulse;
      case 'pill':
        return pill;
      case 'scissors':
        return scissors;
      case 'syringe':
        return syringe;
      case 'trash':
        return trash;
      case 'pencil':
        return pencil;
      case 'info':
        return info;
      case 'alert':
        return alert;
      case 'sparkle':
        return sparkle;
      case 'moon':
        return moon;
      case 'globe':
        return globe;
      case 'lock':
        return lock;
      case 'settings':
        return settings;
      case 'paw':
        return paw;
      case 'qr':
        return qr;
      case 'wallet':
        return wallet;
      case 'gift':
        return gift;
      case 'barcode':
        return barcode;
      case 'droplet':
        return droplet;
      case 'sun':
        return sun;
      case 'monitor':
        return monitor;
      case 'refresh':
        return refresh;
      case 'download':
        return download;
      case 'upload':
        return upload;
      case 'send':
        return send;
      case 'filter':
        return filter;
      case 'scale':
        return scale;
      case 'tooth':
        return tooth;
      case 'clipboard':
        return clipboard;
      case 'logout':
        return logout;
      case 'language':
        return language;
      case 'plusCircle':
        return plusCircle;
      case 'arrowRight':
        return arrowRight;
      case 'arrowUp':
        return arrowUp;
      case 'card2':
        return card2;
      case 'cash':
        return cash;
      case 'cat':
        return cat;
      case 'dog':
        return dog;
      case 'bone':
        return bone;
      case 'eye':
        return eye;
      case 'fire':
        return fire;
      default:
        return info;
    }
  }

  // ---------------------------------------------------------------- tabs
  static const home = 'M3.5 10.5 12 3.5l8.5 7M6 9.5V20h12V9.5M10 20v-5.5h4V20';
  static const chat =
      'M5.5 4h13a2.5 2.5 0 0 1 2.5 2.5v7a2.5 2.5 0 0 1-2.5 2.5H10l-4 3.5v-3.5h-.5A2.5 2.5 0 0 1 3 13.5v-7A2.5 2.5 0 0 1 5.5 4Z';
  static const calendar =
      'M6 5h12a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2ZM4 9.5h16M8.5 2.5v4M15.5 2.5v4';
  static const bag = 'M5 8h14l-1.2 12.5H6.2ZM9 8V6.5a3 3 0 0 1 6 0V8';
  static const person =
      'M12 12a3.8 3.8 0 1 0 0-7.6 3.8 3.8 0 0 0 0 7.6ZM5 20.5c.8-3.6 3.6-5.5 7-5.5s6.2 1.9 7 5.5';

  // ------------------------------------------------------------- glyphs
  static const search =
      'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14ZM16.5 16.5l4.5 4.5';
  static const bell =
      'M18 10.5c0-3.3-2.4-5.9-5.2-6.3V3a.8.8 0 0 0-1.6 0v1.2C8.4 4.6 6 7.2 6 10.5c0 4-1.5 5.2-1.5 5.2h15S18 14.5 18 10.5ZM10.2 19a1.8 1.8 0 0 0 3.6 0';
  static const chevronRight = 'M9.5 5.5 15 12l-5.5 6.5';
  static const chevronLeft = 'M14.5 5.5 9 12l5.5 6.5';
  static const chevronDown = 'M5.5 9.5 12 15l6.5-5.5';
  static const close = 'M6 6l12 12M18 6 6 18';
  static const plus = 'M12 5v14M5 12h14';
  static const minus = 'M5 12h14';
  static const check = 'M4.5 12.5 9.5 17.5 19.5 7';
  static const checkCircle =
      'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM8 12.3l2.7 2.7L16.5 9';
  static const heart =
      'M12 20.5S4.5 16 4.5 10.8A4.4 4.4 0 0 1 12 7.6a4.4 4.4 0 0 1 7.5 3.2c0 5.2-7.5 9.7-7.5 9.7Z';
  static const star =
      'M12 3.6l2.6 5.3 5.8.8-4.2 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.2-4.1 5.8-.8Z';
  static const phone =
      'M8.4 4.2 6.2 4a1.6 1.6 0 0 0-1.9 1.7c.5 5.9 5.5 11 11.4 11.5a1.6 1.6 0 0 0 1.7-1.9l-.3-2.3-3.9-1.3-2 2.1a13.6 13.6 0 0 1-5.1-5.1l2.1-2Z';
  static const clock = 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 7.5V12l3 1.8';
  static const pin =
      'M12 21s6.5-5.8 6.5-10.5a6.5 6.5 0 1 0-13 0C5.5 15.2 12 21 12 21ZM12 13.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z';
  static const doc =
      'M13.5 3.5H7a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8.5ZM13.5 3.5v5h5.5M9 13h6M9 16.5h4';
  static const cart =
      'M3 4.5h2.5L7.8 15h9L19.5 8H6M9.5 19.5a1.3 1.3 0 1 0 0-2.6 1.3 1.3 0 0 0 0 2.6ZM17 19.5a1.3 1.3 0 1 0 0-2.6 1.3 1.3 0 0 0 0 2.6Z';
  static const camera =
      'M4 10.5a2 2 0 0 1 2-2h1.8l1.2-2.2a1.5 1.5 0 0 1 1.3-.8h3.4a1.5 1.5 0 0 1 1.3.8l1.2 2.2H18a2 2 0 0 1 2 2v6.5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2ZM12 17.5a3.3 3.3 0 1 0 0-6.6 3.3 3.3 0 0 0 0 6.6Z';
  static const truck =
      'M3 6.5h10.5v9.5H3ZM13.5 10h3.5l2.5 2.8v3.2h-6ZM6.8 19a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6ZM16.8 19a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6Z';
  static const bookmark = 'M6.5 4h11v16.5L12 16.5 6.5 20.5Z';
  static const stethoscope =
      'M6.5 3v5.5a3.5 3.5 0 0 0 7 0V3M5 3h3M12 3h3M10 12v2.5a4.5 4.5 0 0 0 9 0v-1.5M19 14.8a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6Z';
  static const image =
      'M6 5h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2ZM8.5 11a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM4.5 16.5l4.5-4 3.8 3.4 2.7-2.2 4 3.5';
  static const shield =
      'M12 21.5S4.5 18.3 4.5 12.5V6l7.5-3 7.5 3v6.5c0 5.8-7.5 9-7.5 9Z';
  static const heartPulse =
      'M12 20.5S4.5 16 4.5 10.8A4.4 4.4 0 0 1 12 7.6a4.4 4.4 0 0 1 7.5 3.2c0 5.2-7.5 9.7-7.5 9.7ZM5.5 13h2.8l1.3-2.4 1.7 4.2 1.5-2.8 1.2 1h4.5';
  static const pill =
      'M9.4 4.6a3.4 3.4 0 0 1 4.8 0l5.2 5.2a3.4 3.4 0 1 1-4.8 4.8l-5.2-5.2a3.4 3.4 0 0 1 0-4.8ZM12.8 11.2 16 8';
  static const scissors =
      'M7 8.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM7 20.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM9.3 7.3 19.5 18.5M19.5 5.5 9.3 16.7';
  static const syringe =
      'M15.6 4.2 19.8 8.4M17.6 2.8l3.6 3.6M14.4 5.6 4.8 15.2a1.6 1.6 0 0 0-.4.7l-.7 3.3 3.3-.7c.3-.1.5-.2.7-.4l9.6-9.6ZM11.2 8.8l4 4';
  static const trash =
      'M4.5 6.5h15M9.5 6.5V5a1.2 1.2 0 0 1 1.2-1.2h2.6a1.2 1.2 0 0 1 1.2 1.2v1.5M6.5 6.5l.9 12.3a1.6 1.6 0 0 0 1.6 1.5h6a1.6 1.6 0 0 0 1.6-1.5l.9-12.3M10 10.5v6M14 10.5v6';
  static const pencil =
      'M4 20l1.2-4.6L15.8 4.8a2 2 0 0 1 2.8 0l.6.6a2 2 0 0 1 0 2.8L8.6 18.8ZM14 6.5l3.5 3.5';
  static const info =
      'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 10.8v5.4M12 7.8v.2';
  static const alert = 'M12 3.5 21 19.5H3ZM12 9.5v4.5M12 17v.2';
  static const sparkle =
      'M12 3.5l1.7 4.4 4.4 1.7-4.4 1.7-1.7 4.4-1.7-4.4-4.4-1.7 4.4-1.7ZM18.5 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8Z';
  static const moon = 'M20.5 14.5A8.5 8.5 0 0 1 9.5 3.5a8.5 8.5 0 1 0 11 11Z';
  static const globe =
      'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM3.5 12h17M12 3.5c2.5 2.3 3.8 5.3 3.8 8.5s-1.3 6.2-3.8 8.5c-2.5-2.3-3.8-5.3-3.8-8.5s1.3-6.2 3.8-8.5Z';
  static const lock =
      'M6.5 10.5h11a1.5 1.5 0 0 1 1.5 1.5v7a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19v-7a1.5 1.5 0 0 1 1.5-1.5ZM8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5';
  static const settings =
      'M3.5 8h6M14.5 8h6M3.5 16h4.5M13 16h7.5M12.5 10a2 2 0 1 0 0-4 2 2 0 0 0 0 4ZM11 18a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z';
  static const paw =
      'M12 20.5c3.4 0 5.6-1.9 5.6-4.3 0-2.1-1.7-3.1-2.5-4.7-.7-1.4-1.2-3.3-3.1-3.3s-2.4 1.9-3.1 3.3c-.8 1.6-2.5 2.6-2.5 4.7 0 2.4 2.2 4.3 5.6 4.3Z'
      'M6.5 9.8a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z'
      'M17.5 9.8a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z'
      'M10.3 6.8a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z'
      'M13.7 6.8a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z';
  static const qr =
      'M4 4h6v6H4ZM14 4h6v6h-6ZM4 14h6v6H4ZM14 14h2.8v2.8H14ZM17.2 17.2H20V20h-2.8Z';
  static const wallet =
      'M4 8.5A1.8 1.8 0 0 1 5.8 6.7h12.4a1.8 1.8 0 0 1 1.8 1.8v8a1.8 1.8 0 0 1-1.8 1.8H5.8A1.8 1.8 0 0 1 4 16.5ZM4 11h16M16 14.5h2';
  static const gift =
      'M4.5 10.5h15V20h-15ZM3.5 6.8h17v3.7h-17ZM12 6.8V20M12 6.8H8.8a2.1 2.1 0 1 1 2-2.7c.2 1.5 1.2 2.7 1.2 2.7ZM12 6.8h3.2a2.1 2.1 0 1 0-2-2.7c-.2 1.5-1.2 2.7-1.2 2.7Z';
  static const barcode =
      'M4.5 5v14M7.5 5v14M10.5 5v14M13.5 5v14M16.5 5v14M19.5 5v14';
  static const droplet =
      'M12 3.5c3.5 4.1 5.5 7 5.5 9.7a5.5 5.5 0 1 1-11 0c0-2.7 2-5.6 5.5-9.7Z';
  static const sun =
      'M12 16.5a4.5 4.5 0 1 0 0-9 4.5 4.5 0 0 0 0 9ZM12 2.5v2.5M12 19v2.5M2.5 12h2.5M19 12h2.5M5.3 5.3l1.8 1.8M16.9 16.9l1.8 1.8M18.7 5.3l-1.8 1.8M7.1 16.9l-1.8 1.8';
  static const monitor =
      'M5.5 5.5h13a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2ZM9 20.5h6M12 18.5v2';
  static const refresh = 'M20 12a8 8 0 1 1-2.4-5.7M17.6 2.8v4.5h-4.5';
  static const download = 'M12 4v11M7.5 11.5 12 16l4.5-4.5M4.5 20h15';
  static const upload = 'M12 16V5M7.5 9.5 12 5l4.5 4.5M4.5 20h15';
  static const send = 'M20.5 3.5 3.5 11l6.5 2.5 2.5 6.5ZM10 13.5l10.5-10';
  static const filter = 'M3.5 5.5h17l-6.8 7.5v5.5L10 20.5v-7.5Z';
  static const scale =
      'M12 8.1a1.8 1.8 0 1 0 0-3.6 1.8 1.8 0 0 0 0 3.6ZM5.5 8.5h13l1.5 10.5a1 1 0 0 1-1 1.1H4.9a1 1 0 0 1-1-1.1Z';
  static const tooth =
      'M12 5.4c-1.4-1.6-3.2-2.4-5-2.4-2.6 0-3.6 2.4-3.2 5.4.4 3 1.2 4.6 1.8 7 .4 1.6.6 3.2 1.6 3.6 1.2.4 1.4-1.2 1.6-2.8.4-2 .6-4.4 3.2-4.4s2.8 2.4 3.2 4.4c.2 1.6.4 3.2 1.6 2.8 1-.4 1.2-2 1.6-3.6.6-2.4 1.4-4 1.8-7 .4-3-.6-5.4-3.2-5.4-1.8 0-3.6.8-5 2.4Z';
  static const clipboard =
      'M7 4.5h-1a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-12a2 2 0 0 0-2-2h-1M9.5 2.5h5a1 1 0 0 1 1 1v1.5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1V3.5a1 1 0 0 1 1-1ZM9 12h6M9 15.5h4';
  static const logout =
      'M9.5 20.5H6a2 2 0 0 1-2-2v-13a2 2 0 0 1 2-2h3.5M15.5 16l4.5-4-4.5-4M20 12H9';
  static const language =
      'M3.5 6h8M7.5 3.5V6M5 13.5c1.5-3 4-5.2 7-6.3M4.5 16.5c4-.3 7.2-2.3 9.3-5.8M13.5 21l4-10.5 4 10.5M15 17.8h5';
  static const plusCircle =
      'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM12 8.5v7M8.5 12h7';
  static const arrowRight = 'M4 12h16M13.5 5.5 20 12l-6.5 6.5';
  static const arrowUp = 'M12 20V4M5.5 10.5 12 4l6.5 6.5';
  static const card2 =
      'M6 6.5h12a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2ZM4 10.5h16M6.5 14.5h3';
  static const cash =
      'M3 7.5h18a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1ZM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM6.5 9.5v5M17.5 9.5v5';
  static const cat =
      'M5.5 9.5 4 4.5l4.8 3M18.5 9.5 20 4.5l-4.8 3M12 5.5c-4.5 0-7.5 3.1-7.5 7.2 0 3.9 3.2 6.8 7.5 6.8s7.5-2.9 7.5-6.8c0-4.1-3-7.2-7.5-7.2ZM9.3 11.5v1.5M14.7 11.5v1.5M11.2 14.5h1.6M12 14.5v1.2M6 15.5l2.8.5M18 15.5l-2.8.5';
  static const dog =
      'M7.5 5.5C4.8 6.2 3.8 8.6 4.2 11.5c.2 1.4.8 2.3 1.5 2.3M16.5 5.5c2.7.7 3.7 3.1 3.3 6-.2 1.4-.8 2.3-1.5 2.3M12 5c-4.2 0-7.2 3-7.2 7.3 0 4.4 3.2 7.2 7.2 7.2s7.2-2.8 7.2-7.2c0-4.3-3-7.3-7.2-7.3ZM9.3 10.8v1.5M14.7 10.8v1.5M12 13v1.5M10.2 16.3c.5 1 1.1 1.5 1.8 1.5s1.3-.5 1.8-1.5';
  static const bone =
      'M6.8 17.4a2.2 2.2 0 0 1 0-4.4 2.2 2.2 0 0 1 0-4.4 2.2 2.2 0 0 1 4.4 0l4 4a2.2 2.2 0 0 1 0 4.4 2.2 2.2 0 0 1-4.4 0Z';
  static const eye =
      'M3 12s3.5-5.5 9-5.5S21 12 21 12s-3.5 5.5-9 5.5S3 12 3 12ZM12 14.8a2.8 2.8 0 1 0 0-5.6 2.8 2.8 0 0 0 0 5.6Z';
  static const fire =
      'M12 20.8c3.4 0 6-2.4 6-5.6 0-4.4-4.2-5.6-3.6-10.4-2.6.8-4.2 3-4.2 5.4 0 1.4.6 2 .6 2s-1.8.6-2.4-1c-.8-2.2-.4-3.8.2-5.2C6 8 6 11.6 6 15.2c0 3.2 2.6 5.6 6 5.6Z';
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
            SizedBox.square(
              dimension: T.tap,
              child: Center(child: core),
            ),
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
      duration: reduce
          ? Duration.zero
          : const Duration(milliseconds: T.pressMs),
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
