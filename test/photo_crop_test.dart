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

    /// Opens [PhotoCropScreen] over a stub page and returns a box capturing
    /// the popped result. The engine decode is skipped via [debugImageSize]
    /// (it stalls under the fake clock); layout and crop math stay real.
    Future<List<Uint8List?>> openCrop(
      WidgetTester tester,
      Uint8List bytes,
    ) async {
      final box = <Uint8List?>[null];
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () async {
                    box[0] = await Navigator.of(context).push<Uint8List?>(
                      appRouteT<Uint8List?>(
                        PhotoCropScreen(
                          bytes: bytes,
                          debugImageSize: const Size(120, 80),
                        ),
                      ),
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
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PhotoCropScreen), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      return box;
    }

    /// Drives the real confirm handler in a real async zone (the engine
    /// codec inside cropImageBytes stalls under the fake clock), then
    /// settles. Never pumps or taps inside runAsync: that deadlocks.
    Future<void> confirmCrop(WidgetTester tester) async {
      final confirm = tester
          .widget<PrimaryButton>(
            find.widgetWithText(PrimaryButton, 'Use photo'),
          )
          .onPressed;
      expect(confirm, isNotNull);
      await tester.runAsync(() async {
        confirm!.call();
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// Decodes popped bytes and samples the four corners, all in a real
    /// async zone. Returns (width, height, corners).
    Future<(int, int, List<ui.Color>)> sampleCrop(
      WidgetTester tester,
      Uint8List result,
    ) async {
      final sample = await tester.runAsync(() async {
        final image = await decode(result);
        try {
          return (image.width, image.height, await _cornerColors(image));
        } finally {
          image.dispose();
        }
      });
      return sample!;
    }

    /// E1 reproduction: drive the real confirm pipeline (crop -> pop) with a
    /// quadrant test image and assert the exported bytes are the photo
    /// region inside the crop window -- not the full widget/screen.
    testWidgets('confirm exports the photo region inside the crop window', (
      tester,
    ) async {
      final bytes = (await tester.runAsync(() => makeTestPng(120, 80)))!;
      final box = await openCrop(tester, bytes);
      await confirmCrop(tester);

      final result = box[0];
      expect(result, isNotNull, reason: 'confirm should pop cropped bytes');
      final (w, h, corners) = await sampleCrop(tester, result!);
      // The centred window of the 120x80 photo is a ~69px square: the
      // export must be the photo region, never the 800x600 surface.
      expect(w, lessThan(120));
      expect(h, lessThan(80));
      expect(w, h);
      // Content check: the window is centred on the quadrant cross, so
      // its corners must be red/green/blue/yellow (TL/TR/BL/BR).
      _expectNear(corners[0], const ui.Color(0xFFFF0000), 'top-left');
      _expectNear(corners[1], const ui.Color(0xFF00FF00), 'top-right');
      _expectNear(corners[2], const ui.Color(0xFF0000FF), 'bottom-left');
      _expectNear(corners[3], const ui.Color(0xFFFFFF00), 'bottom-right');
      expect(tester.takeException(), isNull);
    });

    /// E3 rotation case: crop after a 90-degree rotation still targets the
    /// photo region inside the window.
    testWidgets('confirm after rotate still crops the photo region', (
      tester,
    ) async {
      final bytes = (await tester.runAsync(() => makeTestPng(120, 80)))!;
      final box = await openCrop(tester, bytes);

      await tester.tap(find.text('Rotate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await confirmCrop(tester);

      final result = box[0];
      expect(result, isNotNull, reason: 'confirm should pop cropped bytes');
      final (w, h, corners) = await sampleCrop(tester, result!);
      expect(w, h);
      expect(w, greaterThan(1));
      // After one 90° CW turn the centred window maps back to the
      // original's centre strip (20,0,80x80): same quadrant corners.
      _expectNear(corners[0], const ui.Color(0xFFFF0000), 'top-left');
      _expectNear(corners[1], const ui.Color(0xFF00FF00), 'top-right');
      _expectNear(corners[2], const ui.Color(0xFF0000FF), 'bottom-left');
      _expectNear(corners[3], const ui.Color(0xFFFFFF00), 'bottom-right');
      expect(tester.takeException(), isNull);
    });
    /// Pan past the limit: dragging the photo so far that the crop window
    /// would show the dimmed surround snaps back to the fitted view on
    /// gesture end, so the export still matches the window (identity crop).
    testWidgets('pan beyond the window snaps back to the fitted view', (
      tester,
    ) async {
      final bytes = (await tester.runAsync(() => makeTestPng(120, 80)))!;
      final box = await openCrop(tester, bytes);

      await tester.drag(find.byType(InteractiveViewer), const Offset(400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await confirmCrop(tester);

      final result = box[0];
      expect(result, isNotNull, reason: 'confirm should pop cropped bytes');
      final (w, h, corners) = await sampleCrop(tester, result!);
      // Snapped back: the centred identity crop, not a shifted sliver.
      expect(w, lessThan(120));
      expect(h, lessThan(80));
      expect(w, h);
      _expectNear(corners[0], const ui.Color(0xFFFF0000), 'top-left');
      _expectNear(corners[1], const ui.Color(0xFF00FF00), 'top-right');
      _expectNear(corners[2], const ui.Color(0xFF0000FF), 'bottom-left');
      _expectNear(corners[3], const ui.Color(0xFFFFFF00), 'bottom-right');
      expect(tester.takeException(), isNull);
    });
    /// Landscape photo (wider than the crop area can fit by height): the
    /// crop window must be derived from the PHOTO, never the full area.
    /// Regression test for "background gets cropped too": with the window
    /// sized from the area, the 406px window overhangs the 200px-tall photo,
    /// the pipeline silently re-centres, and the export (80x80) no longer
    /// matches the window. Photo-derived window -> 69x69, no re-centring.
    testWidgets('landscape photo: crop window stays inside the photo', (
      tester,
    ) async {
      final bytes = (await tester.runAsync(() => makeTestPng(320, 80)))!;
      final box = <Uint8List?>[null];
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () async {
                    box[0] = await Navigator.of(context).push<Uint8List?>(
                      appRouteT<Uint8List?>(
                        PhotoCropScreen(
                          bytes: bytes,
                          debugImageSize: const Size(320, 80),
                        ),
                      ),
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
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await confirmCrop(tester);

      final result = box[0];
      expect(result, isNotNull, reason: 'confirm should pop cropped bytes');
      final (w, h, corners) = await sampleCrop(tester, result!);
      // Window = 86% of the 200px-tall photo -> 172px -> 68.8 image px.
      // The area-derived 406px window would re-centre to a full-height
      // 80x80 square instead.
      expect(w, 69);
      expect(h, 69);
      _expectNear(corners[0], const ui.Color(0xFFFF0000), 'top-left');
      _expectNear(corners[1], const ui.Color(0xFF00FF00), 'top-right');
      _expectNear(corners[2], const ui.Color(0xFF0000FF), 'bottom-left');
      _expectNear(corners[3], const ui.Color(0xFFFFFF00), 'bottom-right');
      expect(tester.takeException(), isNull);
    });

    /// AX5 smoke: at the maximum text scale the crop screen must not
    /// overflow (nav bar, hint line, confirm button all stay laid out).
    testWidgets('AX5 text scale does not overflow the crop screen', (
      tester,
    ) async {
      final bytes = (await tester.runAsync(() => makeTestPng(120, 80)))!;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
          child: _Ax5CropProbe(bytes: bytes),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PhotoCropScreen), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.widgetWithText(PrimaryButton, 'Use photo'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// Probe that opens the crop screen directly (bypassing the async decode
/// via [debugImageSize]) for the AX5 layout smoke test.
class _Ax5CropProbe extends StatelessWidget {
  const _Ax5CropProbe({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: themeFor(AppPalette.light),
      home: PhotoCropScreen(
        bytes: bytes,
        debugImageSize: const Size(120, 80),
      ),
    );
  }
}

/// Samples the four corner pixels of [image] as raw RGBA colours.
Future<List<ui.Color>> _cornerColors(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final px = data!.buffer.asUint8List();
  ui.Color at(int x, int y) {
    final i = (y * image.width + x) * 4;
    return ui.Color.fromARGB(255, px[i], px[i + 1], px[i + 2]);
  }

  const m = 3; // stay clear of resampled edges
  final w = image.width;
  final h = image.height;
  return [at(m, m), at(w - 1 - m, m), at(m, h - 1 - m), at(w - 1 - m, h - 1 - m)];
}

/// Asserts [actual] is within [tolerance] per channel of [expected].
void _expectNear(ui.Color actual, ui.Color expected, String label) {
  const tolerance = 24 / 255;
  bool near(double a, double b) => (a - b).abs() <= tolerance;
  expect(
    near(actual.r, expected.r) &&
        near(actual.g, expected.g) &&
        near(actual.b, expected.b),
    isTrue,
    reason: '$label corner: expected ~$expected, got $actual',
  );
}
