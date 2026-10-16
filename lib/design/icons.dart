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
    '<path d="$d" stroke="${hex(color)}" stroke-width="$stroke" '
    'stroke-linecap="round" stroke-linejoin="round"/></svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    semanticsLabel: null,
  );

  static String hex(Color c) =>
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
      case 'pawHeart':
        return pawHeart;
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

  /// The CarePaws mark: a paw print whose main pad is a heart — paws for the
  /// patients, a heart for the care. Used for the launcher icon and the
  /// in-app logo so the brand reads as one mark everywhere.
  static const pawHeart =
      'M12 20.5C9.5 18.5 5.2 15.2 5.2 11.8C5.2 9.9 6.7 8.5 8.5 8.5C9.9 8.5 11.1 9.3 12 10.6C12.9 9.3 14.1 8.5 15.5 8.5C17.3 8.5 18.8 9.9 18.8 11.8C18.8 15.2 14.5 18.5 12 20.5Z'
      'M6.5 9.8a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z'
      'M17.5 9.8a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z'
      'M10.3 6.8a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z'
      'M13.7 6.8a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z';

  // BEGIN PAW MARK ARTWORK - hand-maintained.
  // The embrace mark (CarePaws logo): dog and cat in profile,
  // no tile. tool/icon/app_icon.svg holds the launcher master (cream
  // noses touching, heart between; these strings are the in-app variants.

  /// The embrace mark alone (orange disc, no tile) - the in-app logo.
  static const badgeArtwork =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><circle cx="512.6" cy="514.6" r="366.7" fill="#E4843E"/><path d="M875.5,515.2C867.5,491.9 856.6,458.5 824.3,421.1C792.0,383.8 706.2,299.0 681.6,291.2C657.0,283.4 684.1,357.7 676.5,374.4C668.9,391.1 651.3,397.2 636.2,391.7C621.0,386.1 604.4,343.8 585.6,341.1C566.8,338.5 539.1,374.9 523.5,375.7C507.9,376.4 503.8,351.1 492.2,345.6C480.5,340.1 467.2,335.9 453.8,342.4C440.3,348.9 430.8,384.5 411.5,384.6C392.2,384.7 363.6,349.0 337.9,343.0C312.2,337.1 281.0,339.8 257.3,348.8C233.6,357.8 213.8,371.0 195.8,396.8C177.9,422.6 153.4,466.7 149.8,503.7C146.1,540.7 160.6,592.2 174.1,618.9C187.5,645.5 211.9,656.4 230.4,663.7C248.9,670.9 271.0,672.7 284.8,662.4C298.6,652.1 311.3,642.8 313.0,601.6C314.7,560.4 300.6,437.9 295.0,415.4C289.5,392.9 279.6,437.5 279.7,466.6C279.8,495.6 296.6,560.5 295.7,589.4C294.7,618.3 284.9,631.4 273.9,640.0C262.9,648.6 246.2,647.9 229.8,641.3C213.3,634.7 187.4,622.2 175.4,600.3C163.3,578.5 145.1,548.8 157.4,510.1C169.8,471.4 222.1,394.2 249.6,368.0C277.1,341.8 299.3,351.0 322.6,352.6C345.8,354.2 369.5,360.2 389.1,377.6C408.7,395.0 417.2,434.1 440.3,457.0C463.5,479.8 522.2,493.1 528.0,514.6C533.8,536.0 500.8,572.1 474.9,585.6C449.0,599.1 388.3,581.4 372.5,595.8C356.7,610.2 361.9,641.9 380.2,672.0C398.4,702.1 439.3,752.4 481.9,776.3C524.6,800.2 623.1,811.5 636.2,815.4C649.2,819.2 558.4,813.5 560.0,799.4C561.6,785.2 626.6,756.7 645.8,730.2C665.0,703.8 673.8,660.6 675.2,640.6C676.6,620.7 669.5,618.7 654.1,610.6C638.6,602.5 601.2,609.1 582.4,592.0C563.6,574.9 536.5,537.2 541.4,508.2C546.3,479.1 587.8,438.7 611.8,417.9C635.8,397.1 673.3,402.8 685.4,383.4C697.6,363.9 662.6,292.1 684.8,301.4C707.0,310.8 787.3,396.5 818.6,439.7C849.8,482.9 862.8,548.1 872.3,560.6C881.8,573.2 883.5,538.5 875.5,515.2Z" fill="#FEFBF4"/><path d="M643.8,462.1C643.8,462.1 643.4,462.2 643.2,462.1C643.0,462.0 643.0,461.5 642.6,461.4C642.1,461.3 641.1,461.5 640.6,461.4C640.2,461.3 640.4,460.9 640.0,460.8C639.6,460.7 638.5,460.9 638.1,460.8C637.7,460.7 637.8,460.3 637.4,460.2C637.1,460.1 636.5,460.3 636.2,460.2C635.8,460.1 635.8,459.6 635.5,459.5C635.2,459.4 634.8,459.7 634.2,459.5C633.7,459.3 633.2,458.6 632.3,458.2C631.5,457.9 630.2,458.0 629.1,457.6C628.1,457.2 626.9,456.0 625.9,455.7C625.0,455.4 623.9,455.8 623.4,455.7C622.8,455.6 622.9,455.1 622.7,455.0C622.5,454.9 622.3,454.9 622.1,455.0C621.9,455.1 621.8,455.6 621.4,455.7C621.1,455.8 620.8,454.9 620.2,455.7C619.5,456.4 618.0,459.2 617.6,460.2C617.2,461.1 617.7,461.1 617.6,461.4C617.5,461.8 617.1,461.5 617.0,462.1C616.9,462.6 617.1,464.1 617.0,464.6C616.9,465.2 616.4,463.9 616.3,465.3C616.2,466.7 616.2,471.6 616.3,473.0C616.4,474.3 616.9,473.0 617.0,473.6C617.1,474.2 616.9,476.2 617.0,476.8C617.1,477.4 617.5,477.1 617.6,477.4C617.7,477.8 617.5,478.4 617.6,478.7C617.7,479.0 618.1,479.1 618.2,479.4C618.3,479.6 618.1,479.8 618.2,480.0C618.3,480.2 618.7,480.5 618.9,480.6C619.1,480.7 619.2,480.9 619.5,480.6C619.8,480.4 620.5,479.6 620.8,479.4C621.1,479.1 620.6,480.2 621.4,479.4C622.3,478.5 625.1,475.1 625.9,474.2C626.8,473.4 625.1,475.5 626.6,474.2C628.1,473.0 633.4,467.8 634.9,466.6C636.4,465.3 634.9,467.0 635.5,466.6C636.2,466.1 638.1,464.4 638.7,464.0C639.4,463.6 638.9,464.2 639.4,464.0C639.8,463.8 640.7,462.9 641.3,462.7C641.8,462.5 642.2,462.8 642.6,462.7C642.9,462.6 643.0,462.2 643.2,462.1C643.4,462.0 643.8,462.1 643.8,462.1Z" fill="#FEFBF4"/><path d="M405.8,430.1C405.3,429.4 405.2,428.5 403.2,428.2C401.2,427.8 395.3,428.1 393.6,428.2C391.9,428.3 393.4,428.7 393.0,428.8C392.5,428.9 391.5,428.7 391.0,428.8C390.6,428.9 391.0,429.2 390.4,429.4C389.8,429.7 387.8,429.9 387.2,430.1C386.6,430.3 387.2,430.4 386.6,430.7C385.9,431.0 384.2,431.5 383.4,432.0C382.5,432.5 381.9,433.6 381.4,433.9C381.0,434.2 381.1,433.7 380.8,433.9C380.5,434.1 379.7,434.9 379.5,435.2C379.3,435.5 379.8,435.5 379.5,435.8C379.2,436.2 377.9,436.8 377.6,437.1C377.3,437.4 377.9,437.3 377.6,437.8C377.3,438.2 376.0,439.3 375.7,439.7C375.4,440.1 375.6,440.2 375.7,440.3C375.8,440.4 376.1,440.4 376.3,440.3C376.5,440.2 376.6,439.8 377.0,439.7C377.3,439.6 377.7,439.9 378.2,439.7C378.8,439.5 379.6,438.6 380.2,438.4C380.7,438.2 381.1,438.5 381.4,438.4C381.8,438.3 381.9,437.9 382.1,437.8C382.3,437.7 382.3,438.0 382.7,437.8C383.1,437.5 384.1,436.7 384.6,436.5C385.2,436.3 385.6,436.6 385.9,436.5C386.2,436.4 385.9,435.9 386.6,435.8C387.2,435.7 389.1,435.7 389.8,435.8C390.4,435.9 390.3,435.9 390.4,436.5C390.5,437.0 390.2,438.3 390.4,439.0C390.6,439.8 391.5,440.4 391.7,441.0C391.9,441.5 391.6,441.9 391.7,442.2C391.8,442.6 392.1,442.5 392.3,442.9C392.5,443.3 392.5,444.1 393.0,444.8C393.4,445.5 394.5,446.9 394.9,447.4C395.3,447.8 395.2,447.1 395.5,447.4C395.8,447.6 396.4,448.4 396.8,448.6C397.2,448.9 397.4,449.1 398.1,448.6C398.7,448.2 400.2,446.6 400.6,446.1C401.1,445.5 400.5,445.7 400.6,445.4C400.7,445.2 401.2,445.1 401.3,444.8C401.4,444.5 401.2,443.8 401.3,443.5C401.4,443.2 401.8,444.4 401.9,442.9C402.0,441.4 401.7,436.2 401.9,434.6C402.1,433.0 402.9,433.5 403.2,433.3C403.5,433.1 403.4,433.5 403.8,433.3C404.3,433.1 405.4,432.5 405.8,432.0C406.1,431.5 406.2,430.7 405.8,430.1Z" fill="#FEFBF4"/></svg>';

  /// Orange tile + embrace emblem. Full launcher master document.
  static const launcherArtwork =
      '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs><linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1"><stop offset="0" stop-color="#E4843E"/><stop offset="1" stop-color="#D4621A"/></linearGradient></defs><rect width="1024" height="1024" rx="228" ry="228" fill="url(#bg)"/><g transform="translate(512 512) scale(0.72) translate(-512 -512)"><circle cx="512.6" cy="514.6" r="366.7" fill="#E4843E"/><path d="M875.5,515.2C867.5,491.9 856.6,458.5 824.3,421.1C792.0,383.8 706.2,299.0 681.6,291.2C657.0,283.4 684.1,357.7 676.5,374.4C668.9,391.1 651.3,397.2 636.2,391.7C621.0,386.1 604.4,343.8 585.6,341.1C566.8,338.5 539.1,374.9 523.5,375.7C507.9,376.4 503.8,351.1 492.2,345.6C480.5,340.1 467.2,335.9 453.8,342.4C440.3,348.9 430.8,384.5 411.5,384.6C392.2,384.7 363.6,349.0 337.9,343.0C312.2,337.1 281.0,339.8 257.3,348.8C233.6,357.8 213.8,371.0 195.8,396.8C177.9,422.6 153.4,466.7 149.8,503.7C146.1,540.7 160.6,592.2 174.1,618.9C187.5,645.5 211.9,656.4 230.4,663.7C248.9,670.9 271.0,672.7 284.8,662.4C298.6,652.1 311.3,642.8 313.0,601.6C314.7,560.4 300.6,437.9 295.0,415.4C289.5,392.9 279.6,437.5 279.7,466.6C279.8,495.6 296.6,560.5 295.7,589.4C294.7,618.3 284.9,631.4 273.9,640.0C262.9,648.6 246.2,647.9 229.8,641.3C213.3,634.7 187.4,622.2 175.4,600.3C163.3,578.5 145.1,548.8 157.4,510.1C169.8,471.4 222.1,394.2 249.6,368.0C277.1,341.8 299.3,351.0 322.6,352.6C345.8,354.2 369.5,360.2 389.1,377.6C408.7,395.0 417.2,434.1 440.3,457.0C463.5,479.8 522.2,493.1 528.0,514.6C533.8,536.0 500.8,572.1 474.9,585.6C449.0,599.1 388.3,581.4 372.5,595.8C356.7,610.2 361.9,641.9 380.2,672.0C398.4,702.1 439.3,752.4 481.9,776.3C524.6,800.2 623.1,811.5 636.2,815.4C649.2,819.2 558.4,813.5 560.0,799.4C561.6,785.2 626.6,756.7 645.8,730.2C665.0,703.8 673.8,660.6 675.2,640.6C676.6,620.7 669.5,618.7 654.1,610.6C638.6,602.5 601.2,609.1 582.4,592.0C563.6,574.9 536.5,537.2 541.4,508.2C546.3,479.1 587.8,438.7 611.8,417.9C635.8,397.1 673.3,402.8 685.4,383.4C697.6,363.9 662.6,292.1 684.8,301.4C707.0,310.8 787.3,396.5 818.6,439.7C849.8,482.9 862.8,548.1 872.3,560.6C881.8,573.2 883.5,538.5 875.5,515.2Z" fill="#FEFBF4"/><path d="M643.8,462.1C643.8,462.1 643.4,462.2 643.2,462.1C643.0,462.0 643.0,461.5 642.6,461.4C642.1,461.3 641.1,461.5 640.6,461.4C640.2,461.3 640.4,460.9 640.0,460.8C639.6,460.7 638.5,460.9 638.1,460.8C637.7,460.7 637.8,460.3 637.4,460.2C637.1,460.1 636.5,460.3 636.2,460.2C635.8,460.1 635.8,459.6 635.5,459.5C635.2,459.4 634.8,459.7 634.2,459.5C633.7,459.3 633.2,458.6 632.3,458.2C631.5,457.9 630.2,458.0 629.1,457.6C628.1,457.2 626.9,456.0 625.9,455.7C625.0,455.4 623.9,455.8 623.4,455.7C622.8,455.6 622.9,455.1 622.7,455.0C622.5,454.9 622.3,454.9 622.1,455.0C621.9,455.1 621.8,455.6 621.4,455.7C621.1,455.8 620.8,454.9 620.2,455.7C619.5,456.4 618.0,459.2 617.6,460.2C617.2,461.1 617.7,461.1 617.6,461.4C617.5,461.8 617.1,461.5 617.0,462.1C616.9,462.6 617.1,464.1 617.0,464.6C616.9,465.2 616.4,463.9 616.3,465.3C616.2,466.7 616.2,471.6 616.3,473.0C616.4,474.3 616.9,473.0 617.0,473.6C617.1,474.2 616.9,476.2 617.0,476.8C617.1,477.4 617.5,477.1 617.6,477.4C617.7,477.8 617.5,478.4 617.6,478.7C617.7,479.0 618.1,479.1 618.2,479.4C618.3,479.6 618.1,479.8 618.2,480.0C618.3,480.2 618.7,480.5 618.9,480.6C619.1,480.7 619.2,480.9 619.5,480.6C619.8,480.4 620.5,479.6 620.8,479.4C621.1,479.1 620.6,480.2 621.4,479.4C622.3,478.5 625.1,475.1 625.9,474.2C626.8,473.4 625.1,475.5 626.6,474.2C628.1,473.0 633.4,467.8 634.9,466.6C636.4,465.3 634.9,467.0 635.5,466.6C636.2,466.1 638.1,464.4 638.7,464.0C639.4,463.6 638.9,464.2 639.4,464.0C639.8,463.8 640.7,462.9 641.3,462.7C641.8,462.5 642.2,462.8 642.6,462.7C642.9,462.6 643.0,462.2 643.2,462.1C643.4,462.0 643.8,462.1 643.8,462.1Z" fill="#FEFBF4"/><path d="M405.8,430.1C405.3,429.4 405.2,428.5 403.2,428.2C401.2,427.8 395.3,428.1 393.6,428.2C391.9,428.3 393.4,428.7 393.0,428.8C392.5,428.9 391.5,428.7 391.0,428.8C390.6,428.9 391.0,429.2 390.4,429.4C389.8,429.7 387.8,429.9 387.2,430.1C386.6,430.3 387.2,430.4 386.6,430.7C385.9,431.0 384.2,431.5 383.4,432.0C382.5,432.5 381.9,433.6 381.4,433.9C381.0,434.2 381.1,433.7 380.8,433.9C380.5,434.1 379.7,434.9 379.5,435.2C379.3,435.5 379.8,435.5 379.5,435.8C379.2,436.2 377.9,436.8 377.6,437.1C377.3,437.4 377.9,437.3 377.6,437.8C377.3,438.2 376.0,439.3 375.7,439.7C375.4,440.1 375.6,440.2 375.7,440.3C375.8,440.4 376.1,440.4 376.3,440.3C376.5,440.2 376.6,439.8 377.0,439.7C377.3,439.6 377.7,439.9 378.2,439.7C378.8,439.5 379.6,438.6 380.2,438.4C380.7,438.2 381.1,438.5 381.4,438.4C381.8,438.3 381.9,437.9 382.1,437.8C382.3,437.7 382.3,438.0 382.7,437.8C383.1,437.5 384.1,436.7 384.6,436.5C385.2,436.3 385.6,436.6 385.9,436.5C386.2,436.4 385.9,435.9 386.6,435.8C387.2,435.7 389.1,435.7 389.8,435.8C390.4,435.9 390.3,435.9 390.4,436.5C390.5,437.0 390.2,438.3 390.4,439.0C390.6,439.8 391.5,440.4 391.7,441.0C391.9,441.5 391.6,441.9 391.7,442.2C391.8,442.6 392.1,442.5 392.3,442.9C392.5,443.3 392.5,444.1 393.0,444.8C393.4,445.5 394.5,446.9 394.9,447.4C395.3,447.8 395.2,447.1 395.5,447.4C395.8,447.6 396.4,448.4 396.8,448.6C397.2,448.9 397.4,449.1 398.1,448.6C398.7,448.2 400.2,446.6 400.6,446.1C401.1,445.5 400.5,445.7 400.6,445.4C400.7,445.2 401.2,445.1 401.3,444.8C401.4,444.5 401.2,443.8 401.3,443.5C401.4,443.2 401.8,444.4 401.9,442.9C402.0,441.4 401.7,436.2 401.9,434.6C402.1,433.0 402.9,433.5 403.2,433.3C403.5,433.1 403.4,433.5 403.8,433.3C404.3,433.1 405.4,432.5 405.8,432.0C406.1,431.5 406.2,430.7 405.8,430.1Z" fill="#FEFBF4"/></g></svg>';

  /// Splash-morph layer: the orange disc.
  static const splashLayerCircle =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><circle cx="512.6" cy="514.6" r="366.7" fill="#E4843E"/></svg>';

  /// Splash-morph layer: the cream emblem (heart + dividers).
  static const splashLayerEmblem =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><path d="M875.5,515.2C867.5,491.9 856.6,458.5 824.3,421.1C792.0,383.8 706.2,299.0 681.6,291.2C657.0,283.4 684.1,357.7 676.5,374.4C668.9,391.1 651.3,397.2 636.2,391.7C621.0,386.1 604.4,343.8 585.6,341.1C566.8,338.5 539.1,374.9 523.5,375.7C507.9,376.4 503.8,351.1 492.2,345.6C480.5,340.1 467.2,335.9 453.8,342.4C440.3,348.9 430.8,384.5 411.5,384.6C392.2,384.7 363.6,349.0 337.9,343.0C312.2,337.1 281.0,339.8 257.3,348.8C233.6,357.8 213.8,371.0 195.8,396.8C177.9,422.6 153.4,466.7 149.8,503.7C146.1,540.7 160.6,592.2 174.1,618.9C187.5,645.5 211.9,656.4 230.4,663.7C248.9,670.9 271.0,672.7 284.8,662.4C298.6,652.1 311.3,642.8 313.0,601.6C314.7,560.4 300.6,437.9 295.0,415.4C289.5,392.9 279.6,437.5 279.7,466.6C279.8,495.6 296.6,560.5 295.7,589.4C294.7,618.3 284.9,631.4 273.9,640.0C262.9,648.6 246.2,647.9 229.8,641.3C213.3,634.7 187.4,622.2 175.4,600.3C163.3,578.5 145.1,548.8 157.4,510.1C169.8,471.4 222.1,394.2 249.6,368.0C277.1,341.8 299.3,351.0 322.6,352.6C345.8,354.2 369.5,360.2 389.1,377.6C408.7,395.0 417.2,434.1 440.3,457.0C463.5,479.8 522.2,493.1 528.0,514.6C533.8,536.0 500.8,572.1 474.9,585.6C449.0,599.1 388.3,581.4 372.5,595.8C356.7,610.2 361.9,641.9 380.2,672.0C398.4,702.1 439.3,752.4 481.9,776.3C524.6,800.2 623.1,811.5 636.2,815.4C649.2,819.2 558.4,813.5 560.0,799.4C561.6,785.2 626.6,756.7 645.8,730.2C665.0,703.8 673.8,660.6 675.2,640.6C676.6,620.7 669.5,618.7 654.1,610.6C638.6,602.5 601.2,609.1 582.4,592.0C563.6,574.9 536.5,537.2 541.4,508.2C546.3,479.1 587.8,438.7 611.8,417.9C635.8,397.1 673.3,402.8 685.4,383.4C697.6,363.9 662.6,292.1 684.8,301.4C707.0,310.8 787.3,396.5 818.6,439.7C849.8,482.9 862.8,548.1 872.3,560.6C881.8,573.2 883.5,538.5 875.5,515.2Z" fill="#FEFBF4"/></svg>';

  /// Splash-morph layer: the eyes.
  static const splashLayerEyes =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><path d="M643.8,462.1C643.8,462.1 643.4,462.2 643.2,462.1C643.0,462.0 643.0,461.5 642.6,461.4C642.1,461.3 641.1,461.5 640.6,461.4C640.2,461.3 640.4,460.9 640.0,460.8C639.6,460.7 638.5,460.9 638.1,460.8C637.7,460.7 637.8,460.3 637.4,460.2C637.1,460.1 636.5,460.3 636.2,460.2C635.8,460.1 635.8,459.6 635.5,459.5C635.2,459.4 634.8,459.7 634.2,459.5C633.7,459.3 633.2,458.6 632.3,458.2C631.5,457.9 630.2,458.0 629.1,457.6C628.1,457.2 626.9,456.0 625.9,455.7C625.0,455.4 623.9,455.8 623.4,455.7C622.8,455.6 622.9,455.1 622.7,455.0C622.5,454.9 622.3,454.9 622.1,455.0C621.9,455.1 621.8,455.6 621.4,455.7C621.1,455.8 620.8,454.9 620.2,455.7C619.5,456.4 618.0,459.2 617.6,460.2C617.2,461.1 617.7,461.1 617.6,461.4C617.5,461.8 617.1,461.5 617.0,462.1C616.9,462.6 617.1,464.1 617.0,464.6C616.9,465.2 616.4,463.9 616.3,465.3C616.2,466.7 616.2,471.6 616.3,473.0C616.4,474.3 616.9,473.0 617.0,473.6C617.1,474.2 616.9,476.2 617.0,476.8C617.1,477.4 617.5,477.1 617.6,477.4C617.7,477.8 617.5,478.4 617.6,478.7C617.7,479.0 618.1,479.1 618.2,479.4C618.3,479.6 618.1,479.8 618.2,480.0C618.3,480.2 618.7,480.5 618.9,480.6C619.1,480.7 619.2,480.9 619.5,480.6C619.8,480.4 620.5,479.6 620.8,479.4C621.1,479.1 620.6,480.2 621.4,479.4C622.3,478.5 625.1,475.1 625.9,474.2C626.8,473.4 625.1,475.5 626.6,474.2C628.1,473.0 633.4,467.8 634.9,466.6C636.4,465.3 634.9,467.0 635.5,466.6C636.2,466.1 638.1,464.4 638.7,464.0C639.4,463.6 638.9,464.2 639.4,464.0C639.8,463.8 640.7,462.9 641.3,462.7C641.8,462.5 642.2,462.8 642.6,462.7C642.9,462.6 643.0,462.2 643.2,462.1C643.4,462.0 643.8,462.1 643.8,462.1Z" fill="#FEFBF4"/><path d="M405.8,430.1C405.3,429.4 405.2,428.5 403.2,428.2C401.2,427.8 395.3,428.1 393.6,428.2C391.9,428.3 393.4,428.7 393.0,428.8C392.5,428.9 391.5,428.7 391.0,428.8C390.6,428.9 391.0,429.2 390.4,429.4C389.8,429.7 387.8,429.9 387.2,430.1C386.6,430.3 387.2,430.4 386.6,430.7C385.9,431.0 384.2,431.5 383.4,432.0C382.5,432.5 381.9,433.6 381.4,433.9C381.0,434.2 381.1,433.7 380.8,433.9C380.5,434.1 379.7,434.9 379.5,435.2C379.3,435.5 379.8,435.5 379.5,435.8C379.2,436.2 377.9,436.8 377.6,437.1C377.3,437.4 377.9,437.3 377.6,437.8C377.3,438.2 376.0,439.3 375.7,439.7C375.4,440.1 375.6,440.2 375.7,440.3C375.8,440.4 376.1,440.4 376.3,440.3C376.5,440.2 376.6,439.8 377.0,439.7C377.3,439.6 377.7,439.9 378.2,439.7C378.8,439.5 379.6,438.6 380.2,438.4C380.7,438.2 381.1,438.5 381.4,438.4C381.8,438.3 381.9,437.9 382.1,437.8C382.3,437.7 382.3,438.0 382.7,437.8C383.1,437.5 384.1,436.7 384.6,436.5C385.2,436.3 385.6,436.6 385.9,436.5C386.2,436.4 385.9,435.9 386.6,435.8C387.2,435.7 389.1,435.7 389.8,435.8C390.4,435.9 390.3,435.9 390.4,436.5C390.5,437.0 390.2,438.3 390.4,439.0C390.6,439.8 391.5,440.4 391.7,441.0C391.9,441.5 391.6,441.9 391.7,442.2C391.8,442.6 392.1,442.5 392.3,442.9C392.5,443.3 392.5,444.1 393.0,444.8C393.4,445.5 394.5,446.9 394.9,447.4C395.3,447.8 395.2,447.1 395.5,447.4C395.8,447.6 396.4,448.4 396.8,448.6C397.2,448.9 397.4,449.1 398.1,448.6C398.7,448.2 400.2,446.6 400.6,446.1C401.1,445.5 400.5,445.7 400.6,445.4C400.7,445.2 401.2,445.1 401.3,444.8C401.4,444.5 401.2,443.8 401.3,443.5C401.4,443.2 401.8,444.4 401.9,442.9C402.0,441.4 401.7,436.2 401.9,434.6C402.1,433.0 402.9,433.5 403.2,433.3C403.5,433.1 403.4,433.5 403.8,433.3C404.3,433.1 405.4,432.5 405.8,432.0C406.1,431.5 406.2,430.7 405.8,430.1Z" fill="#FEFBF4"/></svg>';

  // END EMBRACE MARK ARTWORK

  /// Renders [badgeArtwork] — the embrace mark alone, no tile — at [size].
  /// This is what the in-app [LogoMark] uses.
  static Widget badgeIcon({required double size}) =>
      SvgPicture.string(badgeArtwork, width: size, height: size);
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

  /// Web/desktop hover only: a pointer hover lifts brightness a touch and
  /// shows the click cursor. Touch devices never enter this state, so touch
  /// press behaviour is unchanged.
  bool _hover = false;

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

    // Hover/focus overlays paint as *foreground* decorations: they change
    // zero layout. (A Stack wrapper here used to collapse the child to its
    // intrinsic width and pin it top-left — the tab bar visibly jumped left
    // on hover. Never wrap press content in a Stack for an overlay.)
    if (_hover && interactive) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: content,
      );
    }

    if (_focused && interactive) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: T.terracottaDeep, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: content,
      );
    }

    if (!interactive) return content;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
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
      ),
    );
  }
}
