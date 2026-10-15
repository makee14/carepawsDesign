import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/icons.dart';

/// Guards the Variant-A logo (mark v5, refined): the in-app mark is the
/// badge alone — no tile, no wordmark. The four animation groups keep stable
/// IDs so the splash morph can address them, and every color is a stamped
/// named token (tool/sync_icons_dart.py owns the mapping).
void main() {
  group('CarePaws mark v5 artwork', () {
    test('badgeArtwork is the badge alone, with the four group IDs', () {
      expect(Ic.badgeArtwork, contains('id="cp-circle"'));
      expect(Ic.badgeArtwork, contains('id="cp-dog"'));
      expect(Ic.badgeArtwork, contains('id="cp-cat"'));
      expect(Ic.badgeArtwork, contains('id="cp-heart"'));
      expect(Ic.badgeArtwork, contains('#E4843E'));
      expect(Ic.badgeArtwork, contains('#FEFBF4'));
      expect(Ic.badgeArtwork, isNot(contains('<rect')));
      expect(Ic.badgeArtwork, isNot(contains('linearGradient')));
      expect(Ic.badgeArtwork, isNot(contains('var(')));
    });

    test('launcherArtwork is the cream tile + badge', () {
      expect(Ic.launcherArtwork, contains('<rect'));
      expect(Ic.launcherArtwork, contains('#FEFBF4'));
      expect(Ic.launcherArtwork, contains('id="cp-badge"'));
      expect(Ic.launcherArtwork, isNot(contains('var(')));
    });

    test('launcherForegroundArtwork is transparent (no tile rect)', () {
      expect(Ic.launcherForegroundArtwork, isNot(contains('<rect')));
      expect(Ic.launcherForegroundArtwork, contains('id="cp-badge"'));
    });

    test('badgeNoCircleArtwork has silhouettes only, heart merged', () {
      expect(Ic.badgeNoCircleArtwork, contains('id="cp-dog"'));
      expect(Ic.badgeNoCircleArtwork, contains('id="cp-cat"'));
      expect(Ic.badgeNoCircleArtwork, contains('id="cp-heart"'));
      expect(Ic.badgeNoCircleArtwork, contains('mask'));
      expect(Ic.badgeNoCircleArtwork, isNot(contains('id="cp-circle"')));
    });

    test('splash layers compose the badge and carry the same groups', () {
      expect(Ic.splashLayerCircle, contains('id="cp-circle"'));
      expect(Ic.splashLayerDog, contains('id="cp-dog"'));
      expect(Ic.splashLayerCat, contains('id="cp-cat"'));
      expect(Ic.splashLayerHeart, contains('id="cp-heart"'));
      for (final layer in [
        Ic.splashLayerCircle,
        Ic.splashLayerDog,
        Ic.splashLayerCat,
        Ic.splashLayerHeart,
      ]) {
        expect(layer, contains('viewBox="0 0 1024 1024"'));
        expect(layer, isNot(contains('var(')));
      }
    });

    test('no vtracer-era artwork remains', () {
      for (final art in [
        Ic.badgeArtwork,
        Ic.launcherArtwork,
        Ic.launcherForegroundArtwork,
        Ic.badgeNoCircleArtwork,
      ]) {
        expect(art, isNot(contains('clipPath')));
        expect(art, isNot(contains('embrace')));
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
