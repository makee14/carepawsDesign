import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Immediately-failing transport: every probe comes back 401, so _save
/// reaches the key-result sheet without touching the network.
class _FailFast extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 401);
}

Future<AppStore> pumpShell(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final s = AppStore(
    now: DateTime(2026, 10, 13, 9, 40),
    ai: AiService(client: _FailFast()),
  );
  await tester.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: const RootShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('full shell: Gemini sheet Done dismisses the sheet', (
    tester,
  ) async {
    await pumpShell(tester);
    await openTab(tester, 'Profile');
    await tester.tap(find.text('CarePaws AI').first);
    await tester.pumpAndSettle();
    expect(find.text('Gemini'), findsOneWidget);
    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(CupertinoTextField),
      'AIzaSyBogusKeyForTestingPurposesOnly123',
    );
    await tester.tap(find.text('Save key'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('is ready').evaluate().isNotEmpty ||
          find.text('Key saved').evaluate().isNotEmpty ||
          find.text('That key was not accepted').evaluate().isNotEmpty,
      isTrue,
      reason: 'expected the key-result sheet to be visible',
    );
    await tester.tap(find.widgetWithText(PrimaryButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PrimaryButton, 'Done'), findsNothing,
        reason: 'Done must dismiss the sheet');
    // And we are back on the AI settings screen, not stranded.
    expect(find.text('Gemini'), findsOneWidget);
  });
}
