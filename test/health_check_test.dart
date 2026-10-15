import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/icons.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/triage/health_result_sheet.dart';
import 'package:carepaws/screens/triage_screen.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/services/dataset_store.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

/// Fake AI backend: answers triage calls with a canned result and records
/// which pet name it was asked about.
class _FakeAi extends AiService {
  _FakeAi(this.canned) {
    status = AiStatus.live;
  }

  final TriageResult canned;
  String? lastPetName;

  @override
  Future<TriageResult> triage({
    required String petName,
    required String species,
    required String text,
    Uint8List? photo,
    String? photoMime,
    String ownerFirstName = '',
  }) async {
    lastPetName = petName;
    return canned;
  }
}

TriageResult _canned({
  TriageRoute route = TriageRoute.homeCare,
  int urgency = 0,
}) => TriageResult(
  route: route,
  title: 'Mild stomach upset',
  summary: 'This looks like a mild, short-lived stomach upset.',
  urgency: urgency,
  bullets: ['Ate something unusual'],
  redFlags: ['Repeated vomiting'],
  homeCare: ['Offer small sips of water'],
  nextStep: 'Watch for 24 hours',
);

Future<AppStore> _pumpCheck(
  WidgetTester tester,
  _FakeAi ai, {
  String? preselectedPetId,
  void Function(TriageResult?)? onComplete,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final s = AppStore(ai: ai, now: DateTime(2026, 10, 14, 10, 0));
  s.accountEmail = 'mark@example.com';
  await tester.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: TriageScreen(
          preselectedPetId: preselectedPetId,
          onComplete: onComplete,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

void main() {
  group('health models', () {
    test('fromTriage maps urgency and threads the step-0 petId', () {
      final r = HealthCheckResult.fromTriage(
        id: 'hc1',
        petId: 'p2',
        triage: _canned(route: TriageRoute.emergency, urgency: 2),
        answers: const [],
        createdAt: DateTime(2026, 10, 14),
      );
      expect(r.petId, 'p2');
      expect(r.urgency, Urgency.urgent);
      expect(r.route, TriageRoute.emergency);
      expect(r.recommendation, isNotEmpty);

      final mild = HealthCheckResult.fromTriage(
        id: 'hc2',
        petId: 'p1',
        triage: _canned(urgency: 0),
        answers: const [],
        createdAt: DateTime(2026, 10, 14),
      );
      expect(mild.urgency, Urgency.low);
      final high = HealthCheckResult.fromTriage(
        id: 'hc3',
        petId: 'p1',
        triage: _canned(route: TriageRoute.book, urgency: 2),
        answers: const [],
        createdAt: DateTime(2026, 10, 14),
      );
      expect(high.urgency, Urgency.high);
      final moderate = HealthCheckResult.fromTriage(
        id: 'hc4',
        petId: 'p1',
        triage: _canned(urgency: 1),
        answers: const [],
        createdAt: DateTime(2026, 10, 14),
      );
      expect(moderate.urgency, Urgency.moderate);
    });

    test('dataset round-trip preserves every field', () {
      final r = HealthCheckResult.fromTriage(
        id: 'hc9',
        petId: 'p2',
        triage: _canned(route: TriageRoute.chat, urgency: 1),
        answers: const [
          HealthAnswer(questionId: 'concern', question: 'Q?', answer: 'A!'),
        ],
        createdAt: DateTime(2026, 10, 14, 9, 30),
      );
      final back = DatasetStore.decodeHealthChecks(
        DatasetStore.encodeHealthChecks([r]),
      )!;
      expect(back, hasLength(1));
      final d = back.first;
      expect(d.id, 'hc9');
      expect(d.petId, 'p2');
      expect(d.summary, r.summary);
      expect(d.urgency, Urgency.moderate);
      expect(d.recommendation, r.recommendation);
      expect(d.route, TriageRoute.chat);
      expect(d.sections, hasLength(r.sections.length));
      expect(d.answers.first.answer, 'A!');
    });

    test('urgency badge contrast is >= 4.5:1 at every level', () {
      for (final u in Urgency.values) {
        final c = urgencyBadgeColors(u);
        expect(
          _contrast(c.bg, c.fg),
          greaterThanOrEqualTo(4.5),
          reason: 'badge $u below 4.5:1',
        );
      }
    });
  });

  group('app store', () {
    test('latestHealthResult returns the newest result for the pet', () {
      final s = AppStore(now: DateTime(2026, 10, 14, 10));
      expect(s.latestHealthResult('p1'), isNull);
      s.recordHealthResult(
        HealthCheckResult.fromTriage(
          id: 'a',
          petId: 'p1',
          triage: _canned(),
          answers: const [],
          createdAt: DateTime(2026, 10, 14, 9),
        ),
      );
      s.recordHealthResult(
        HealthCheckResult.fromTriage(
          id: 'b',
          petId: 'p2',
          triage: _canned(),
          answers: const [],
          createdAt: DateTime(2026, 10, 14, 9, 30),
        ),
      );
      s.recordHealthResult(
        HealthCheckResult.fromTriage(
          id: 'c',
          petId: 'p1',
          triage: _canned(),
          answers: const [],
          createdAt: DateTime(2026, 10, 14, 10),
        ),
      );
      expect(s.latestHealthResult('p1')!.id, 'c');
      expect(s.latestHealthResult('p2')!.id, 'b');
      expect(s.latestHealthResult('nope'), isNull);
    });
  });

  group('stepped flow', () {
    testWidgets('cannot proceed without a pet selected', (tester) async {
      await _pumpCheck(tester, _FakeAi(_canned()));
      // Step 0 shows the pet list and the progress header.
      expect(find.text('Which pet is this check for?'), findsOneWidget);
      expect(find.text('Step 1 of 6'), findsOneWidget);
      // Continue is disabled and the hint explains why.
      final btn = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Continue'),
      );
      expect(btn.onPressed, isNull);
      expect(find.text('Choose a pet to start the check'), findsOneWidget);
    });

    testWidgets('result uses the step-0 pet (wrong-pet-name regression)', (
      tester,
    ) async {
      final ai = _FakeAi(_canned());
      final store = await _pumpCheck(tester, ai);
      // Pick Mochi (p2), NOT the first pet.
      await tester.tap(find.text('Mochi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      // Answer the four questions with the first option each.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byType(PressScale).first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();
      }
      // Photo step: run without a photo.
      expect(find.text('Step 6 of 6'), findsOneWidget);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Run health check'));
      await tester.pumpAndSettle();

      // The AI was asked about Mochi, and the result is filed under p2.
      expect(ai.lastPetName, 'Mochi');
      expect(find.text('Health check — Mochi'), findsOneWidget);
      expect(find.text('Health check — Biscuit'), findsNothing);
      final latest = store.latestHealthResult('p2');
      expect(latest, isNotNull);
      expect(latest!.petId, 'p2');
      expect(store.latestHealthResult('p1'), isNull);
    });

    testWidgets('send posts to the clinic; decline keeps it private', (
      tester,
    ) async {
      final ai = _FakeAi(_canned(urgency: 1));
      final store = await _pumpCheck(tester, ai);
      await tester.tap(find.text('Biscuit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byType(PressScale).first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(PrimaryButton, 'Run health check'));
      await tester.pumpAndSettle();

      // Moderate urgency recommends sending.
      expect(
        find.textContaining('We recommend sending this to the clinic'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(PrimaryButton, 'Send to clinic'));
      await tester.pumpAndSettle();
      expect(find.text('Sent to the clinic team.'), findsOneWidget);
      expect(
        store.messages.any((m) => m.threadId == 'th_clinic' && m.petId == 'p1'),
        isTrue,
      );
    });

    testWidgets('declining to send is not a dead end', (tester) async {
      final ai = _FakeAi(_canned());
      await _pumpCheck(tester, ai);
      await tester.tap(find.text('Biscuit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byType(PressScale).first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(PrimaryButton, 'Run health check'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SecondaryButton, 'Don\u2019t send'));
      await tester.pumpAndSettle();
      expect(find.text('Kept private to this check.'), findsOneWidget);
      // The results screen is still fully usable.
      expect(find.byType(UrgencyBadge), findsOneWidget);
    });

    testWidgets('booking entry returns the raw result via onComplete', (
      tester,
    ) async {
      TriageResult? returned;
      final ai = _FakeAi(_canned(route: TriageRoute.book, urgency: 1));
      await _pumpCheck(
        tester,
        ai,
        preselectedPetId: 'p1',
        onComplete: (r) => returned = r,
      );
      // Preselected pet: step 0 already satisfied, Continue enabled.
      final btn = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Continue'),
      );
      expect(btn.onPressed, isNotNull);
      await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byType(PressScale).first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(PrimaryButton, 'Run health check'));
      await tester.pumpAndSettle();
      expect(returned, isNotNull);
      expect(returned!.route, TriageRoute.book);
    });
  });

  group('result sheet (Stream B contract)', () {
    testWidgets('sheet renders the result summary-first', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(now: DateTime(2026, 10, 14, 10));
      s.accountEmail = 'mark@example.com';
      final r = HealthCheckResult.fromTriage(
        id: 's1',
        petId: 'p1',
        triage: _canned(urgency: 1),
        answers: const [],
        createdAt: DateTime(2026, 10, 14, 9),
      );
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        AppScope(
          store: s,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: Builder(
              builder: (ctx) => CupertinoButton(
                onPressed: () => HealthCheckResultSheet.show(ctx, r),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(UrgencyBadge), findsOneWidget);
      expect(find.text(r.summary), findsOneWidget);
      expect(find.text('What to do next'), findsOneWidget);
      // Details sit behind expandable sections (G2).
      expect(find.text('Possible causes'), findsOneWidget);
      expect(find.textContaining('Ate something unusual'), findsNothing);
      await tester.tap(find.text('Possible causes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ate something unusual'), findsOneWidget);
    });
  });
}

double _relativeLuminance(Color c) {
  double ch(double s) {
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}
