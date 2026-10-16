import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/chats_screen.dart';
import 'package:carepaws/screens/triage/health_result_sheet.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reduced-motion (disableAnimations) must never crash an expand/collapse.
/// AnimatedSize with Duration.zero completes its controller synchronously
/// inside performLayout and throws "mutated in its own performLayout" — the
/// reduced-motion path must skip AnimatedSize entirely, the way Home's
/// clinic-info card does.
Widget _stillness(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );

HealthCheckResult _fakeResult() => HealthCheckResult(
      id: 'r1',
      petId: 'p1',
      summary: 'Looks fine',
      urgency: Urgency.low,
      recommendation: 'Keep an eye on it.',
      route: TriageRoute.homeCare,
      sections: const [
        HealthSection(title: 'Feeding', body: 'Feed twice a day.'),
      ],
      createdAt: DateTime(2026, 10, 13, 10, 0),
    );

void main() {
  group('reduced motion expand/collapse', () {
    testWidgets('chats how-it-works expands without throwing', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      final store = AppStore(now: DateTime(2026, 10, 13, 10, 0));
      await tester.pumpWidget(
        _stillness(
          AppScope(
            store: store,
            child: CupertinoApp(
              theme: themeFor(AppPalette.light),
              home: const ChatsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('How clinic chat works'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Message the clinic team directly'),
        findsOneWidget,
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets('health result section expands without throwing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        _stillness(
          CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: CupertinoPageScaffold(
              child: SafeArea(
                child: SingleChildScrollView(
                  child: HealthCheckResultView(
                    result: _fakeResult(),
                    petName: 'Biscuit',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Feeding'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Feed twice a day.'), findsOneWidget);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });
}
