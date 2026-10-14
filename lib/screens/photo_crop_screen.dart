import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../widgets/common.dart';

/// Crop/edit step before a picked photo becomes a pet portrait or the owner
/// photo. Pan/zoom with [InteractiveViewer] inside a fixed square crop
/// window (dimmed surround), rotate in 90° steps, then Confirm.
///
/// Returns the cropped PNG bytes via [Navigator.pop], or null on Cancel.
/// Cropping uses `dart:ui` only — no new packages.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _viewer = TransformationController();

  /// 90° clockwise steps applied to the source image.
  int _turns = 0;

  int _imgW = 0;
  int _imgH = 0;
  bool _decodeFailed = false;
  bool _confirming = false;

  /// Geometry captured from the last layout pass, needed to map the fixed
  /// crop window back into image pixels on confirm.
  _CropGeometry? _geom;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _viewer.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (!mounted || w < 1 || h < 1) return;
      setState(() {
        _imgW = w;
        _imgH = h;
      });
    } catch (_) {
      if (mounted) setState(() => _decodeFailed = true);
    }
  }

  void _rotate() {
    setState(() {
      _turns = (_turns + 1) % 4;
      // Reset the view: keeping the old transform across a 90° rotation
      // would fling the image somewhere unpredictable.
      _viewer.value = Matrix4.identity();
    });
  }

  Future<void> _confirm() async {
    final geom = _geom;
    if (_confirming || geom == null || _imgW < 1) return;
    setState(() => _confirming = true);
    try {
      final out = await cropImageBytes(
        widget.bytes,
        geom.displayedRect(_viewer.value),
        _turns,
      );
      if (!mounted) return;
      Navigator.of(context).pop(out);
    } catch (_) {
      // Practically unreachable after the decode in initState succeeded; if
      // it ever happens, keep the old portrait rather than a blank photo.
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Crop photo'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _imgW < 1 ? null : _rotate,
          child: Semantics(
            button: true,
            label: 'Rotate 90 degrees',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ic.svg(Ic.refresh, size: 20, color: p.accent),
                const SizedBox(width: 4),
                Text('Rotate', style: Type.body(p).copyWith(color: p.accent)),
              ],
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildCropArea(p)),
            Padding(
              padding: const EdgeInsets.fromLTRB(T.s20, T.s12, T.s20, T.s20),
              child: PrimaryButton(
                label: 'Use photo',
                icon: Ic.check,
                busy: _confirming,
                onPressed: (_imgW < 1 || _decodeFailed || _confirming)
                    ? null
                    : _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropArea(AppPalette p) {
    if (_decodeFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(T.s24),
          child: Text(
            'That photo could not be read. Try a different one.',
            textAlign: TextAlign.center,
            style: Type.body(p).copyWith(color: p.textSecondary),
          ),
        ),
      );
    }
    if (_imgW < 1) {
      return const Center(child: CupertinoActivityIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;
        // Pixel dims of the image as currently rotated.
        final pw = (_turns.isOdd ? _imgH : _imgW).toDouble();
        final ph = (_turns.isOdd ? _imgW : _imgH).toDouble();
        final fit = math.min(availW / pw, availH / ph);
        final childW = pw * fit;
        final childH = ph * fit;
        // Fixed square window, centred; the surround is dimmed.
        final side = math.min(availW, availH) * 0.86;
        final window = Rect.fromCenter(
          center: Offset(availW / 2, availH / 2),
          width: side,
          height: side,
        );
        _geom = _CropGeometry(
          availW: availW,
          availH: availH,
          childW: childW,
          childH: childH,
          pixelW: pw,
          pixelH: ph,
          window: window,
        );
        return Stack(
          children: [
            // The viewer fills the area (constrained: the child is a Center
            // so the image keeps its contain-fit size); the transform maps
            // child points (== viewer points at identity) to screen points.
            InteractiveViewer(
              transformationController: _viewer,
              minScale: 0.6,
              maxScale: 6.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              panEnabled: true,
              scaleEnabled: true,
              child: Center(
                child: SizedBox(
                  width: childW,
                  height: childH,
                  child: RotatedBox(
                    quarterTurns: _turns,
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      semanticLabel: 'Photo to crop',
                    ),
                  ),
                ),
              ),
            ),
            // Dimmed surround with a square hole + white frame. Pointer-
            // transparent so pan/zoom gestures reach the viewer.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _CropOverlay(window)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: IgnorePointer(
                child: Text(
                  'Drag to position · pinch to zoom',
                  textAlign: TextAlign.center,
                  style: Type.footnote(p)
                      .copyWith(color: CupertinoColors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Layout facts needed to turn the fixed window rect into image pixels.
class _CropGeometry {
  const _CropGeometry({
    required this.availW,
    required this.availH,
    required this.childW,
    required this.childH,
    required this.pixelW,
    required this.pixelH,
    required this.window,
  });

  final double availW;
  final double availH;
  final double childW;
  final double childH;

  /// Pixel dims of the image as displayed (after rotation).
  final double pixelW;
  final double pixelH;
  final Rect window;

  /// The window rect in displayed-image pixel space, via the inverse of the
  /// viewer's current transform. The image is centred in the child area.
  Rect displayedRect(Matrix4 transform) {
    final childRect = MatrixUtils.transformRect(
      Matrix4.inverted(transform),
      window,
    );
    final dx = (availW - childW) / 2;
    final dy = (availH - childH) / 2;
    final scale = pixelW / childW;
    return Rect.fromLTWH(
      (childRect.left - dx) * scale,
      (childRect.top - dy) * scale,
      childRect.width * scale,
      childRect.height * scale,
    );
  }
}

/// Dims everything outside [window] and draws its frame.
class _CropOverlay extends CustomPainter {
  _CropOverlay(this.window);

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(window)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      hole,
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.45),
    );
    canvas.drawRect(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_CropOverlay oldDelegate) => oldDelegate.window != window;
}

/// Maps a rect in the *displayed* (rotated) image's pixel space back to the
/// *original* image's pixel space. [quarterTurns] counts 90° clockwise steps,
/// matching [RotatedBox].
@visibleForTesting
Rect unrotateRect(Rect displayed, int quarterTurns, int w, int h) {
  switch (quarterTurns % 4) {
    case 0:
      return displayed;
    case 1: // 90° CW: (dx, dy) -> (dy, h - dx); dims swap to h x w.
      return Rect.fromLTWH(
        displayed.top,
        h - displayed.right,
        displayed.height,
        displayed.width,
      );
    case 2: // 180°: (dx, dy) -> (w - dx, h - dy).
      return Rect.fromLTWH(
        w - displayed.right,
        h - displayed.bottom,
        displayed.width,
        displayed.height,
      );
    case 3: // 270° CW: (dx, dy) -> (w - dy, dx); dims swap to h x w.
      return Rect.fromLTWH(
        w - displayed.bottom,
        displayed.left,
        displayed.height,
        displayed.width,
      );
  }
  return displayed;
}

/// Crops [displayed] (in displayed-image pixels) out of [bytes] as a square
/// PNG, honouring [quarterTurns] of 90° clockwise rotation. Returns null when
/// the rect misses the image entirely.
@visibleForTesting
Future<Uint8List?> cropImageBytes(
  Uint8List bytes,
  Rect displayed,
  int quarterTurns,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    var region = unrotateRect(
      displayed,
      quarterTurns,
      image.width,
      image.height,
    ).intersect(Rect.fromLTWH(0, 0, w, h));
    // The window is square; clamping at the image edge can shave one side,
    // so re-centre a square on what survived.
    final side = math.min(region.width, region.height);
    if (side < 1) return null;
    region = Rect.fromCenter(
      center: region.center,
      width: side,
      height: side,
    ).intersect(Rect.fromLTWH(0, 0, w, h));
    final outSide = side.round().clamp(1, 2048);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      region,
      Rect.fromLTWH(0, 0, outSide.toDouble(), outSide.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final out = await recorder.endRecording().toImage(outSide, outSide);
    try {
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      final png = data?.buffer.asUint8List();
      return (png == null || png.isEmpty) ? null : png;
    } finally {
      out.dispose();
    }
  } finally {
    image.dispose();
    codec.dispose();
  }
}
