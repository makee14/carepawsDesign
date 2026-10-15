import 'dart:typed_data';

import 'package:carepaws/services/photo_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the photo-quality fix (B1): storage keeps proper resolution,
/// render sites decode at display size × DPR and never upscale.
void main() {
  group('PhotoStore caps', () {
    test('1600px longest edge covers 3x full-bleed rendering', () {
      // 390pt × 3x = 1170px of real pixels needed; the cap keeps headroom
      // without letting SharedPreferences bloat without bound.
      expect(PhotoStore.maxEdge, 1600);
      expect(PhotoStore.maxEdge, greaterThan(390 * 3));
    });

    test('JPEG quality preserves fur detail', () {
      expect(PhotoStore.jpegQuality, 85);
    });
  });

  group('PhotoStore.memoryImage', () {
    testWidgets('decodes at display width × devicePixelRatio', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) => PhotoStore.memoryImage(
                context,
                Uint8List(0),
                displayWidthPt: 100,
              ),
            ),
          ),
        ),
      );
      final img = tester.widget<Image>(find.byType(Image));
      // The widget funnels cacheWidth through a ResizeImage wrapper.
      final resized = img.image as ResizeImage;
      expect(resized.width, 300);
      expect(img.fit, BoxFit.cover);
    });

    testWidgets('decode width never exceeds the store ceiling', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 4),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) => PhotoStore.memoryImage(
                context,
                Uint8List(0),
                displayWidthPt: 1000,
              ),
            ),
          ),
        ),
      );
      final img = tester.widget<Image>(find.byType(Image));
      final resized = img.image as ResizeImage;
      expect(resized.width, PhotoStore.maxEdge);
    });
  });
}
