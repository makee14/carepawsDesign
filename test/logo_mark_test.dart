import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/icons.dart';

/// Guards the embrace-paw logo: the in-app mark is the paw alone — no tile,
/// no wordmark. One mark everywhere: launcher icon, splash, and in-app logo
/// all share the paw.
void main() {
  group('CarePaws paw mark artwork', () {
    test('badgeArtwork is the paw alone, orange on transparent', () {
      expect(Ic.badgeArtwork, contains('<ellipse'));
      expect(Ic.badgeArtwork, contains('<path'));
      expect(Ic.badgeArtwork, contains('<circle'));
      expect(Ic.badgeArtwork, contains('#E4843E'));
      expect(Ic.badgeArtwork, isNot(contains('<rect')));
      expect(Ic.badgeArtwork, isNot(contains('linearGradient')));
      expect(Ic.badgeArtwork, isNot(contains('var(')));
      expect(Ic.badgeArtwork, isNot(contains('cp-dog')));
      expect(Ic.badgeArtwork, isNot(contains('cp-cat')));
      expect(Ic.badgeArtwork, isNot(contains('cp-heart')));
    });

    test('launcherArtwork is the orange tile + cream paw', () {
      expect(Ic.launcherArtwork, contains('<rect'));
      expect(Ic.launcherArtwork, contains('linearGradient'));
      expect(Ic.launcherArtwork, contains('#FEFBF4'));
    });

    test('splash layers compose the paw: pad plus four toes', () {
      expect(Ic.splashLayerPad, contains('<path'));
      expect(Ic.splashLayerPad, contains('<circle'));
      for (final toe in [
        Ic.splashLayerToe1,
        Ic.splashLayerToe2,
        Ic.splashLayerToe3,
        Ic.splashLayerToe4,
      ]) {
        expect(toe, contains('<ellipse'));
        expect(toe, contains('viewBox="0 0 1024 1024"'));
        expect(toe, isNot(contains('var(')));
      }
      expect(Ic.splashLayerPad, contains('viewBox="0 0 1024 1024"'));
    });
  });

  testWidgets('LogoMark renders the paw artwork, not the tile', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(home: Center(child: LogoMark(size: 120))),
    );
    await tester.pump();
    final pic = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final loader = pic.bytesLoader;
    // SvgStringLoader hides its string, but == compares it: the mark must
    // be the paw, not the full launcher tile.
    expect(loader, SvgStringLoader(Ic.badgeArtwork));
    expect(loader, isNot(SvgStringLoader(Ic.launcherArtwork)));
    expect(
      find.bySemanticsLabel('CarePaws Veterinary Clinic logo'),
      findsOneWidget,
    );
  });
}
