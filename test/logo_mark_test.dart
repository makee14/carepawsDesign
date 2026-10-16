import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/icons.dart';

/// Guards the embrace logo: the in-app mark is the dog-and-cat embrace alone
/// — no tile, no wordmark. One mark everywhere: launcher icon, splash, and
/// in-app logo all share the embrace.
void main() {
  group('CarePaws embrace mark artwork', () {
    test('badgeArtwork is the embrace alone, orange on transparent', () {
      expect(Ic.badgeArtwork, contains('<circle'));
      expect(Ic.badgeArtwork, contains('<path'));
      expect(Ic.badgeArtwork, contains('#E4843E'));
      expect(Ic.badgeArtwork, isNot(contains('<rect')));
      expect(Ic.badgeArtwork, isNot(contains('linearGradient')));
      expect(Ic.badgeArtwork, isNot(contains('var(')));
    });

    test('launcherArtwork is the orange tile + embrace emblem', () {
      expect(Ic.launcherArtwork, contains('<rect'));
      expect(Ic.launcherArtwork, contains('linearGradient'));
      expect(Ic.launcherArtwork, contains('#FEFBF4'));
    });

    test('splash layers compose the embrace: disc, emblem, eyes', () {
      expect(Ic.splashLayerCircle, contains('<circle'));
      expect(Ic.splashLayerEmblem, contains('<path'));
      expect(Ic.splashLayerEyes, contains('<path'));
      for (final layer in [
        Ic.splashLayerCircle,
        Ic.splashLayerEmblem,
        Ic.splashLayerEyes,
      ]) {
        expect(layer, contains('viewBox="0 0 1024 1024"'));
        expect(layer, isNot(contains('var(')));
      }
    });
  });

  testWidgets('LogoMark renders the embrace artwork, not the tile', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(home: Center(child: LogoMark(size: 120))),
    );
    await tester.pump();
    final pic = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final loader = pic.bytesLoader;
    // SvgStringLoader hides its string, but == compares it: the mark must
    // be the embrace, not the full launcher tile.
    expect(loader, SvgStringLoader(Ic.badgeArtwork));
    expect(loader, isNot(SvgStringLoader(Ic.launcherArtwork)));
    expect(
      find.bySemanticsLabel('CarePaws Veterinary Clinic logo'),
      findsOneWidget,
    );
  });
}
