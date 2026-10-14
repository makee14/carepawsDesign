import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/icons.dart';

/// Guards the Variant-A logo swap (2026-10-14): the in-app mark is the
/// badge alone — no tile, no wordmark, no leftover embrace-paw paths.
void main() {
  group('CarePaws mark v4 artwork', () {
    test('badgeArtwork is the badge alone', () {
      expect(Ic.badgeArtwork, contains('clipPath'));
      expect(Ic.badgeArtwork, contains('#E4843E'));
      expect(Ic.badgeArtwork, contains('#FEFBF4'));
      expect(Ic.badgeArtwork, isNot(contains('linearGradient')));
      expect(Ic.badgeArtwork, isNot(contains('<rect')));
    });

    test('launcherArtwork is the cream tile + badge', () {
      expect(Ic.launcherArtwork, contains('<rect'));
      expect(Ic.launcherArtwork, contains('#FEFBF4'));
      expect(Ic.launcherArtwork, contains('clipPath'));
    });

    test('launcherForegroundArtwork is transparent (no tile rect)', () {
      expect(Ic.launcherForegroundArtwork, isNot(contains('<rect')));
      expect(Ic.launcherForegroundArtwork, contains('clipPath'));
    });

    test('no embrace-paw artwork remains', () {
      for (final art in [
        Ic.badgeArtwork,
        Ic.launcherArtwork,
        Ic.launcherForegroundArtwork,
      ]) {
        expect(art, isNot(contains('embrace')));
        expect(art, isNot(contains('M32 62 L41 70')));
      }
    });
  });

  testWidgets('LogoMark renders the badge artwork, not the tile', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(home: Center(child: LogoMark(size: 120))),
    );
    await tester.pump();
    final pic = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final loader = pic.bytesLoader;
    // SvgStringLoader hides its string, but == compares it: the mark must
    // be the badge, not the full launcher tile.
    expect(loader, SvgStringLoader(Ic.badgeArtwork));
    expect(loader, isNot(SvgStringLoader(Ic.launcherArtwork)));
    expect(
      find.bySemanticsLabel('CarePaws Veterinary Clinic logo'),
      findsOneWidget,
    );
  });
}
