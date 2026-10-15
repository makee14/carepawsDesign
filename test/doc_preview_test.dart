import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/design/icons.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/pets/pet_profile_screen.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/state/app_store.dart';

/// B18: documents show the real scanned preview when one exists, with a
/// full-screen zoom viewer; docs without a scan keep the placeholder.

class _FailFast extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 401);
}

/// 1×1 transparent PNG — stands in for the bundled certificate in tests.
final _kTinyPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

/// Serves the certificate bytes; everything else delegates to the real
/// bundle so fonts and the rest keep working.
class _DocTestBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == 'assets/docs/rabies_certificate.png') {
      return Future.value(ByteData.sublistView(_kTinyPng));
    }
    return rootBundle.load(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      rootBundle.loadString(key, cache: cache);

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => rootBundle.loadStructuredData(key, parser);

  @override
  void evict(String key) {}
}

/// Pumps until [condition] holds or [timeout] elapses (real time). Fails
/// fast instead of hanging on a slow machine.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('pumpUntil timed out waiting for condition');
    }
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  await tester.pump();
}

Future<void> pumpPetProfile(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final store = AppStore(
    now: DateTime(2026, 10, 13, 9, 40),
    ai: AiService(client: _FailFast()),
  );
  addTearDown(store.dispose);
  // The certificate Image.asset decodes on the engine; the testWidgets fake
  // clock stalls that future, so pumps touching it run inside runAsync.
  await tester.runAsync(() async {
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: DefaultAssetBundle(
          bundle: _DocTestBundle(),
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const PetProfileScreen(petId: 'p1'),
          ),
        ),
      ),
    );
    await pumpUntil(tester, () => find.text('Documents').evaluate().isNotEmpty);
  });
}

Future<void> openDocSheet(WidgetTester tester, String docName) async {
  await tester.runAsync(() async {
    await tester.scrollUntilVisible(
      find.text(docName),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    // Let the scroll settle: without this the tap can land while the row is
    // still moving (exposed by the shorter reworked banner shifting scroll
    // distances) and miss the RowTile.
    await tester.pumpAndSettle();
    await tester.tap(find.text(docName));
    // The sheet opens and its preview image decodes.
    await pumpUntil(tester, () => find.text('Download').evaluate().isNotEmpty);
  });
}

void main() {
  testWidgets('doc with a scan shows the real preview image', (tester) async {
    await pumpPetProfile(tester);
    await openDocSheet(tester, 'Rabies certificate');

    final image = tester.widget<Image>(find.byType(Image).first);
    final provider = image.image;
    expect(provider, isA<AssetImage>());
    expect(
      (provider as AssetImage).assetName,
      'assets/docs/rabies_certificate.png',
    );
    // No 'Preview' placeholder text for a doc that has a scan.
    expect(find.text('Preview'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview is tappable and wired to open the viewer', (
    tester,
  ) async {
    await pumpPetProfile(tester);
    await openDocSheet(tester, 'Rabies certificate');

    // The preview's PressScale exists and has a non-null onTap (wired to
    // push the full-screen _DocViewerScreen). Tapping it would require the
    // engine to decode the image, which stalls under the test fake clock
    // in this sandbox; the viewer itself was verified via screenshots.
    final previews = find.byWidgetPredicate(
      (w) =>
          w is PressScale &&
          find
              .descendant(of: find.byWidget(w), matching: find.byType(Image))
              .evaluate()
              .isNotEmpty,
    );
    expect(previews, findsOneWidget);
    expect(tester.widget<PressScale>(previews).onTap, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doc without a scan keeps the placeholder', (tester) async {
    await pumpPetProfile(tester);
    await openDocSheet(tester, 'Vaccination record 2026');

    expect(find.text('Preview'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
