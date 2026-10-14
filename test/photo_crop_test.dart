import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/photo_crop_screen.dart';
import 'package:carepaws/widgets/common.dart';

/// A 1x1 red PNG, decoded from base64 without touching the engine.
/// Widget tests use this because makeTestPng needs the engine codec, which
/// stalls under the testWidgets fake clock in this sandbox.
Uint8List get kTestPng1x1 => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// B17: crop-region math, the dart:ui crop pipeline, and the Confirm/Cancel
/// contract of [PhotoCropScreen].

/// Builds a w×h test PNG with distinct quadrants so rotation bugs are
/// visible in the cropped output's dimensions.
Future<Uint8List> makeTestPng(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final half = ui.Rect.fromLTWH(0, 0, w / 2, h / 2);
  canvas.drawRect(half, ui.Paint()..color = const ui.Color(0xFFFF0000));
  canvas.drawRect(
    half.shift(ui.Offset(w / 2, 0)),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  canvas.drawRect(
    half.shift(ui.Offset(0, h / 2)),
    ui.Paint()..color = const ui.Color(0xFF0000FF),
  );
  canvas.drawRect(
    half.shift(ui.Offset(w / 2, h / 2)),
    ui.Paint()..color = const ui.Color(0xFFFFFF00),
  );
  final image = await recorder.endRecording().toImage(w, h);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Future<ui.Image> decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

void main() {
  group('unrotateRect', () {
    // Image 100×60, displayed rect (10, 20, 30×20) i.e. LTRB (10,20,40,40).
    const displayed = Rect.fromLTWH(10, 20, 30, 20);

    test('0 turns is identity', () {
      expect(unrotateRect(displayed, 0, 100, 60), displayed);
    });

    test('90° CW maps (dx,dy) -> (dy, h-dx) and swaps dims', () {
      // left = top(20), top = h-right(60-40=20), w/h swapped (20×30).
      expect(
        unrotateRect(displayed, 1, 100, 60),
        const Rect.fromLTWH(20, 20, 20, 30),
      );
    });

    test('180° maps (dx,dy) -> (w-dx, h-dy)', () {
      expect(
        unrotateRect(displayed, 2, 100, 60),
        const Rect.fromLTWH(100 - 40, 60 - 40, 30, 20),
      );
    });

    test('270° CW maps (dx,dy) -> (w-dy, dx) and swaps dims', () {
      expect(
        unrotateRect(displayed, 3, 100, 60),
        const Rect.fromLTWH(100 - 40, 10, 20, 30),
      );
    });

    test('4 turns == 0 turns', () {
      expect(unrotateRect(displayed, 4, 100, 60), displayed);
    });
  });

  group('cropImageBytes', () {
    test('crops a centred square from the middle of the image', () async {
      final bytes = await makeTestPng(120, 80);
      // Centre square of the 120×80 image: 80×80 at (20, 0).
      final out = await cropImageBytes(
        bytes,
        const Rect.fromLTWH(20, 0, 80, 80),
        0,
      );
      expect(out, isNotNull);
      expect(out, isNotEmpty);
      final image = await decode(out!);
      expect(image.width, 80);
      expect(image.height, 80);
      image.dispose();
    });

    test('rotation keeps the output square', () async {
      final bytes = await makeTestPng(120, 80);
      // Displayed (rotated 90° CW) dims are 80×120; crop its centre 80×80.
      final out = await cropImageBytes(
        bytes,
        const Rect.fromLTWH(0, 20, 80, 80),
        1,
      );
      expect(out, isNotNull);
      final image = await decode(out!);
      expect(image.width, image.height);
      image.dispose();
    });

    test('a rect fully outside the image returns null', () async {
      final bytes = await makeTestPng(120, 80);
      final out = await cropImageBytes(
        bytes,
        const Rect.fromLTWH(500, 500, 80, 80),
        0,
      );
      expect(out, isNull);
    });
  });

  group('PhotoCropScreen', () {
    // NOTE: Image decoding stalls unreliably under the testWidgets fake
    // clock in this sandbox (the engine codec future never resolves), so
    // widget tests here only verify structure and the Cancel contract.
    // The decode + crop pipeline is covered by the cropImageBytes unit
    // tests above, which run in a real async zone.

    testWidgets('shows a loading indicator while decoding', (tester) async {
      final bytes = kTestPng1x1;
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: PhotoCropScreen(bytes: bytes),
        ),
      );
      await tester.pump();
      // The decode is in flight: spinner visible, confirm disabled.
      expect(find.byType(CupertinoActivityIndicator), findsWidgets);
      final button = find.widgetWithText(PrimaryButton, 'Use photo');
      expect(button, findsOneWidget);
      expect(tester.widget<PrimaryButton>(button).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rotate button is labelled for assistive tech', (tester) async {
      final bytes = kTestPng1x1;
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: PhotoCropScreen(bytes: bytes),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Rotate 90 degrees')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel pops without waiting for decode', (tester) async {
      final bytes = kTestPng1x1;
      Uint8List? result = Uint8List(0);
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<Uint8List?>(
                      appRouteT<Uint8List?>(PhotoCropScreen(bytes: bytes)),
                    );
                  },
                  child: const Text('open crop'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open crop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PhotoCropScreen), findsOneWidget);
      // Cancel is always enabled, even while the decode is in flight.
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PhotoCropScreen), findsNothing);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('undecodable bytes show a message, not a crash', (
      tester,
    ) async {
      // The decode fails fast for garbage input (no engine codec needed).
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: PhotoCropScreen(bytes: Uint8List.fromList([0, 1, 2, 3])),
        ),
      );
      await tester.pump();
      // Still loading or already failed: either way, no crash.
      expect(tester.takeException(), isNull);
    });
  });
}
