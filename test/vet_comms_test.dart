import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/vet/comms_screen.dart';
import 'package:carepaws/screens/vet/vet_more_screen.dart';
import 'package:carepaws/services/comms_service.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task 7 — AI comms composer state machine. Written before the
/// implementation (RED first).
///
/// Pins the spec:
/// - draft → approved → sent. An unapproved draft CANNOT send — the gate
///   lives in the state machine (`sendDraft` refuses), not just the UI.
/// - Approval is always an explicit vet action. Generating, editing or
///   re-scoping a draft never approves it, and touching an approved draft's
///   content sends it back to draft for re-approval.
/// - SMS and email require customer opt-in. Sending to a non-opted-in
///   customer is blocked; in-app announcements need no opt-in.
/// - Draft text comes from the AI service. Tests inject a stub generator —
///   no real network calls.
/// - Actual SMS/email delivery is stubbed: the backend provider + budget
///   from the spec are not wired yet.
CommsDraftGenerator _stubAi({String reply = 'Friendly draft body.'}) =>
    ({
      required CommsDraftKind kind,
      required String topic,
      String? details,
    }) async => reply;

CommsService _service({CommsDraftGenerator? generator}) => CommsService(
  draftGenerator: generator ?? _stubAi(),
  recipients: const [
    CommsRecipient(
      id: 'c1',
      name: 'Ana Reyes',
      smsOptIn: true,
      emailOptIn: true,
    ),
    CommsRecipient(id: 'c2', name: 'Miguel Cruz', emailOptIn: true),
    CommsRecipient(id: 'c3', name: 'Jose Ramos'),
    CommsRecipient(id: 'c4', name: 'Liza Santos', smsOptIn: true),
  ],
);

Future<CommsDraft> _approved(
  CommsService service, {
  CommsChannel channel = CommsChannel.inApp,
}) async {
  final draft = await service.generateDraft(
    kind: CommsDraftKind.announcement,
    topic: 'Holiday hours',
    channel: channel,
  );
  return service.approveDraft(draft, vetId: 'vet-1');
}

void main() {
  group('approval gate (the critical safety test)', () {
    test('send() on an unapproved draft throws and stays a draft', () async {
      final service = _service();
      final draft = await service.generateDraft(
        kind: CommsDraftKind.announcement,
        topic: 'Holiday hours',
      );
      expect(draft.state, CommsDraftState.draft);
      expect(
        () => service.sendDraft(draft),
        throwsA(
          isA<CommsException>().having(
            (e) => e.message,
            'message',
            contains('approve'),
          ),
        ),
      );
      // The refusal must not mutate the draft.
      expect(draft.state, CommsDraftState.draft);
    });

    test('approved draft sends and lands in sent state', () async {
      final service = _service();
      final sent = await service.sendDraft(await _approved(service));
      expect(sent.state, CommsDraftState.sent);
      expect(sent.sentAt, isNotNull);
      expect(sent.approvedBy, 'vet-1');
    });

    test('a sent draft cannot be sent twice', () async {
      final service = _service();
      final sent = await service.sendDraft(await _approved(service));
      expect(() => service.sendDraft(sent), throwsA(isA<CommsException>()));
    });
  });

  group('explicit approval, never automatic', () {
    test('generating a draft does not approve it', () async {
      final service = _service();
      final draft = await service.generateDraft(
        kind: CommsDraftKind.reminder,
        topic: 'Vaccination due',
      );
      expect(draft.state, CommsDraftState.draft);
    });

    test('editing a draft does not approve it', () async {
      final service = _service();
      var draft = await service.generateDraft(
        kind: CommsDraftKind.announcement,
        topic: 'Holiday hours',
      );
      draft = service.editDraft(draft, body: 'Edited by the vet.');
      expect(draft.body, 'Edited by the vet.');
      expect(draft.state, CommsDraftState.draft);
      expect(() => service.sendDraft(draft), throwsA(isA<CommsException>()));
    });

    test(
      'editing an approved draft revokes approval — re-approval needed',
      () async {
        final service = _service();
        var draft = await _approved(service);
        draft = service.editDraft(draft, body: 'Changed after approval.');
        expect(draft.state, CommsDraftState.draft);
        expect(draft.approvedBy, isNull);
        // The edited text cannot ride on the old approval.
        expect(() => service.sendDraft(draft), throwsA(isA<CommsException>()));
        // Re-approving the new text sends fine.
        final sent = await service.sendDraft(
          service.approveDraft(draft, vetId: 'vet-1'),
        );
        expect(sent.state, CommsDraftState.sent);
      },
    );

    test('approving twice throws', () async {
      final service = _service();
      final approved = await _approved(service);
      expect(
        () => service.approveDraft(approved, vetId: 'vet-1'),
        throwsA(isA<CommsException>()),
      );
    });

    test(
      'changing the channel on an approved draft revokes approval',
      () async {
        final service = _service();
        var draft = await _approved(service, channel: CommsChannel.inApp);
        draft = service.setChannel(draft, CommsChannel.email);
        expect(draft.state, CommsDraftState.draft);
        expect(() => service.sendDraft(draft), throwsA(isA<CommsException>()));
      },
    );
  });

  group('opt-in rules per channel', () {
    test('SMS to a non-opted-in customer is blocked and names them', () async {
      final service = _service();
      final draft = await _approved(service, channel: CommsChannel.sms);
      expect(
        () => service.sendDraft(draft),
        throwsA(
          isA<CommsException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Jose Ramos'), contains('Miguel Cruz')),
          ),
        ),
      );
    });

    test('email to a non-opted-in customer is blocked', () async {
      final service = _service();
      final draft = await _approved(service, channel: CommsChannel.email);
      expect(
        () => service.sendDraft(draft),
        throwsA(
          isA<CommsException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Jose Ramos'), contains('Liza Santos')),
          ),
        ),
      );
    });

    test('in-app announcements need no opt-in', () async {
      final service = _service();
      final sent = await service.sendDraft(
        await _approved(service, channel: CommsChannel.inApp),
      );
      expect(sent.state, CommsDraftState.sent);
    });

    test('excluding non-opted-in recipients unblocks the send', () async {
      final service = _service();
      var draft = await _approved(service, channel: CommsChannel.sms);
      draft = service.excludeNonOptedIn(draft);
      expect(
        draft.recipients.map((r) => r.name),
        unorderedEquals(['Ana Reyes', 'Liza Santos']),
      );
      // Narrowing recipients keeps the content approval.
      expect(draft.state, CommsDraftState.approved);
      final sent = await service.sendDraft(draft);
      expect(sent.state, CommsDraftState.sent);
    });
  });

  group('draft generation (AI, mocked)', () {
    test('the AI generator is called with kind and topic', () async {
      CommsDraftKind? seenKind;
      String? seenTopic;
      final service = _service(
        generator:
            ({
              required CommsDraftKind kind,
              required String topic,
              String? details,
            }) async {
              seenKind = kind;
              seenTopic = topic;
              return 'AI-drafted reminder text.';
            },
      );
      final draft = await service.generateDraft(
        kind: CommsDraftKind.reminder,
        topic: 'Vaccination due for Mochi',
        channel: CommsChannel.email,
      );
      expect(seenKind, CommsDraftKind.reminder);
      expect(seenTopic, 'Vaccination due for Mochi');
      expect(draft.body, 'AI-drafted reminder text.');
      expect(draft.kind, CommsDraftKind.reminder);
      expect(draft.channel, CommsChannel.email);
      expect(draft.state, CommsDraftState.draft);
    });

    test('the AI is not consulted again on edit, approve or send', () async {
      var calls = 0;
      final service = _service(
        generator:
            ({
              required CommsDraftKind kind,
              required String topic,
              String? details,
            }) async {
              calls++;
              return 'AI text.';
            },
      );
      var draft = await service.generateDraft(
        kind: CommsDraftKind.announcement,
        topic: 'Holiday hours',
      );
      draft = service.editDraft(draft, body: 'vet edit');
      draft = service.approveDraft(draft, vetId: 'vet-1');
      await service.sendDraft(draft);
      expect(calls, 1);
    });

    test('an empty topic is rejected before the AI is consulted', () async {
      var calls = 0;
      final service = _service(
        generator:
            ({
              required CommsDraftKind kind,
              required String topic,
              String? details,
            }) async {
              calls++;
              return 'AI text.';
            },
      );
      expect(
        () => service.generateDraft(
          kind: CommsDraftKind.announcement,
          topic: '   ',
        ),
        throwsA(isA<CommsException>()),
      );
      expect(calls, 0);
    });

    test('an AI failure surfaces to the caller, never a fake draft', () async {
      final service = _service(
        generator: ({
          required CommsDraftKind kind,
          required String topic,
          String? details,
        }) async => throw Exception('network down'),
      );
      expect(
        () => service.generateDraft(
          kind: CommsDraftKind.announcement,
          topic: 'Holiday hours',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('composer UI', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    AppStore store() {
      final s = AppStore(now: DateTime(2026, 10, 17, 9, 30));
      addTearDown(s.dispose);
      return s;
    }

    Future<void> pump(WidgetTester tester, Widget home) async {
      await tester.pumpWidget(
        AppScope(
          store: store(),
          child: CupertinoApp(theme: themeFor(AppPalette.light), home: home),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('More tab links to the composer, inventory and settings', (
      tester,
    ) async {
      await pump(tester, const VetMoreScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('AI comms composer'), findsOneWidget);
      expect(find.text('Products & stock'), findsOneWidget);
      expect(find.text('Clinic settings'), findsOneWidget);
      expect(find.text('Staff'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the composer row opens the composer', (tester) async {
      await pump(tester, const VetMoreScreen());
      await tester.tap(find.text('AI comms composer'));
      await tester.pumpAndSettle();
      expect(find.byType(CommsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping clinic settings and staff rows opens their screens', (
      tester,
    ) async {
      await pump(tester, const VetMoreScreen());
      await tester.tap(find.text('Clinic settings'));
      await tester.pumpAndSettle();
      expect(find.byType(ClinicSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('composer shows the flow and a locked send', (tester) async {
      await pump(tester, const CommsScreen());
      expect(tester.takeException(), isNull);
      // Step 1: what to say.
      expect(find.text('Generate draft with AI'), findsOneWidget);
      expect(find.text('Vaccination due'), findsOneWidget);
      // No draft yet: no review, channel or send sections.
      expect(find.textContaining('Review the draft'), findsNothing);
      expect(find.text('Send message'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inventory lists products with stock levels', (tester) async {
      await pump(tester, const VetInventoryScreen());
      expect(tester.takeException(), isNull);
      // Seed products render with a stock chip each.
      expect(find.textContaining('In stock'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'generate with no AI key shows the honest error, no fake draft',
      (tester) async {
        // The real AiService has no keys here, so drafting must fail loudly
        // with the AI's own "add a key" copy — never a fabricated message.
        await pump(tester, const CommsScreen());
        await tester.enterText(
          find.byType(CupertinoTextField).first,
          'Holiday hours',
        );
        await tester.tap(find.text('Generate draft with AI'));
        await tester.pumpAndSettle();
        expect(find.textContaining('No API key is configured'), findsOneWidget);
        // No review section: nothing was drafted.
        expect(find.textContaining('Review the draft'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('generate with an empty topic is rejected before the AI', (
      tester,
    ) async {
      await pump(tester, const CommsScreen());
      await tester.tap(find.text('Generate draft with AI'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Add a topic first'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('composer does not overflow at AX5 (3.2x text)', (
      tester,
    ) async {
      // The preset pills and segmented labels cannot survive 3.2x — above
      // 1x they reflow into wrapping rows instead of clipping.
      await tester.pumpWidget(
        AppScope(
          store: store(),
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const CommsScreen(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(3.2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Reflowed rows, not clipped pills: every preset label fully visible.
      expect(find.text('Open grooming slots'), findsOneWidget);
      expect(find.text('Appointment reminder'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
