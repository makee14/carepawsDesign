import 'package:carepaws/data/models.dart';
import 'package:carepaws/data/seed.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/chat_thread_screen.dart';
import 'package:carepaws/screens/vet/vet_chats_screen.dart';
import 'package:carepaws/services/auth_store.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task 5 — vet chats screen: the full clinic inbox.
///
/// Written before the implementation (RED first). Pins the spec:
/// - one row per clinic thread (all threads, not the customer's own view);
/// - unread badges count incoming customer messages per thread;
/// - a shared triage handoff surfaces its context banner (the triageSummary
///   from the [ChatKind.triageHandoff] message — surfaced, never re-derived);
/// - threads sort by most-recent activity;
/// - tapping a thread opens [ChatThreadScreen] with replyRole vet.
DateTime _now() => DateTime(2026, 10, 17, 9, 30);

AppStore _store() {
  final s = AppStore(now: _now());
  addTearDown(s.dispose);
  return s;
}

ChatMessage _customerMessage(AppStore s, {required DateTime at}) => ChatMessage(
  id: 'c${at.microsecondsSinceEpoch}',
  threadId: 'th_clinic',
  author: ChatAuthor.vetAssistant,
  text: 'Hi, is Mochi\u2019s vaccination slot still free?',
  at: at,
  sentByMe: true,
  petId: 'p2',
);

void _shareTriage(AppStore s) {
  s.handOffToClinic(
    pet: s.pets.first,
    result: const TriageResult(
      route: TriageRoute.book,
      title: 'Vomiting \u2014 needs a visit',
      summary: 'Two episodes this morning.',
      urgency: 2,
    ),
  );
}

Thread _extraThread() => const Thread(
  id: 'th_extra',
  title: 'Second customer',
  subtitle: '',
  icon: 'chat',
  pinned: false,
  isAi: false,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('inbox rows', () {
    test('lists one row per clinic thread (AI thread excluded)', () {
      final s = _store();
      final items = buildVetInbox(s);
      expect(items.map((i) => i.threadId), ['th_clinic']);
    });

    test('rows carry customer + pet, preview and timestamp', () {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 5))),
      );
      final item = buildVetInbox(s)
          .singleWhere((i) => i.threadId == 'th_clinic');
      // Seed owner is Marco Rivera; the seeded clinic message is about Mochi.
      expect(item.title, contains('Marco'));
      expect(item.title, contains('Mochi'));
      expect(item.preview, contains('vaccination slot'));
      expect(item.timeLabel, isNotEmpty);
    });

    test('threads sort by most-recent activity, newest first', () {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(hours: 3))),
      );
      s.pushMessage(
        ChatMessage(
          id: 'old',
          threadId: 'th_extra',
          author: ChatAuthor.vetAssistant,
          text: 'Older thread.',
          at: _now().subtract(const Duration(days: 2)),
          sentByMe: true,
        ),
      );
      final items = buildVetInbox(
        s,
        threads: [...Seed.threads, _extraThread()],
      );
      expect(items.map((i) => i.threadId), ['th_clinic', 'th_extra']);
    });

    test('search filters by customer or pet name', () {
      final s = _store();
      s.pushMessage(
        ChatMessage(
          id: 'extra',
          threadId: 'th_extra',
          author: ChatAuthor.vetAssistant,
          text: 'Question about Biscuit.',
          at: _now().subtract(const Duration(minutes: 10)),
          sentByMe: true,
          petId: 'p1',
        ),
      );
      expect(
        filterVetInbox(
          buildVetInbox(s, threads: [...Seed.threads, _extraThread()]),
          'biscuit',
        ),
        hasLength(1),
      );
      expect(
        filterVetInbox(
          buildVetInbox(s, threads: [...Seed.threads, _extraThread()]),
          'marco',
        ),
        isNotEmpty,
      );
      expect(
        filterVetInbox(
          buildVetInbox(s, threads: [...Seed.threads, _extraThread()]),
          'no-such-name',
        ),
        isEmpty,
      );
    });
  });

  group('unread badges', () {
    test('counts incoming customer messages per thread', () {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 30))),
      );
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 5))),
      );
      expect(s.vetUnread('th_clinic'), 2);
      expect(buildVetInbox(s).single.unread, 2);
    });

    test('a shared triage handoff counts as unread', () {
      final s = _store();
      _shareTriage(s);
      // The handoff message itself is new customer-side demand; the
      // auto-reply that follows is staff-side and never counts.
      expect(s.vetUnread('th_clinic'), 1);
    });

    test('staff replies and system messages never count as unread', () {
      final s = _store();
      // Seed clinic thread holds a staff message + a system auto-reply.
      expect(s.vetUnread('th_clinic'), 0);
    });

    test('markVetThreadRead clears the badge', () {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 5))),
      );
      expect(s.vetUnread('th_clinic'), 1);
      s.markVetThreadRead('th_clinic');
      expect(s.vetUnread('th_clinic'), 0);
    });
  });

  group('triage handoff banner', () {
    test('unshared threads carry no handoff context', () {
      final s = _store();
      expect(buildVetInbox(s).single.triageSummary, isNull);
    });

    test('a shared handoff surfaces its summary (never re-derived)', () {
      final s = _store();
      _shareTriage(s);
      final item = buildVetInbox(s).single;
      expect(item.triageSummary, 'Two episodes this morning.');
      expect(item.pet?.id, s.pets.first.id);
    });

    test('the latest handoff wins when several were shared', () {
      final s = _store();
      _shareTriage(s);
      s.handOffToClinic(
        pet: s.pets[1],
        result: const TriageResult(
          route: TriageRoute.chat,
          title: 'Limping \u2014 needs a visit',
          summary: 'Newer summary.',
          urgency: 1,
        ),
      );
      final item = buildVetInbox(s).single;
      expect(item.triageSummary, 'Newer summary.');
      expect(item.pet?.id, s.pets[1].id);
    });
  });

  group('vet chats screen', () {
    Future<AppStore> pumpInbox(WidgetTester tester, AppStore store) async {
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const VetChatsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('renders a row per thread with unread badges', (tester) async {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 5))),
      );
      await pumpInbox(tester, s);
      expect(tester.takeException(), isNull);
      // Customer + pet title.
      expect(find.textContaining('Marco'), findsWidgets);
      // Unread badge shows the count.
      expect(find.text('1', skipOffstage: false), findsOneWidget);
    });

    testWidgets('triage handoff threads show the handoff banner', (
      tester,
    ) async {
      final s = _store();
      _shareTriage(s);
      await pumpInbox(tester, s);
      expect(tester.takeException(), isNull);
      expect(find.text('Triage handoff'), findsWidgets);
      expect(find.text('Two episodes this morning.'), findsOneWidget);
    });

    testWidgets('tapping a thread opens the chat thread with replyRole vet', (
      tester,
    ) async {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 5))),
      );
      await pumpInbox(tester, s);
      await tester.tap(find.textContaining('Marco').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ChatThreadScreen), findsOneWidget);
      final thread = tester.widget<ChatThreadScreen>(
        find.byType(ChatThreadScreen),
      );
      expect(thread.threadId, 'th_clinic');
      expect(thread.replyRole, StaffRole.vet);
    });

    testWidgets('tapping a handoff thread passes handoff context along', (
      tester,
    ) async {
      final s = _store();
      _shareTriage(s);
      await pumpInbox(tester, s);
      await tester.tap(find.textContaining('Marco').first);
      await tester.pumpAndSettle();
      final thread = tester.widget<ChatThreadScreen>(
        find.byType(ChatThreadScreen),
      );
      expect(thread.replyRole, StaffRole.vet);
      expect(thread.openedWithPetId, s.pets.first.id);
      expect(thread.triageSummary, 'Two episodes this morning.');
    });

    testWidgets('opening a thread clears its unread badge', (tester) async {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 5))),
      );
      await pumpInbox(tester, s);
      expect(s.vetUnread('th_clinic'), 1);
      await tester.tap(find.textContaining('Marco').first);
      await tester.pumpAndSettle();
      // Back to the inbox: the thread was marked read on open.
      Navigator.of(tester.element(find.byType(ChatThreadScreen))).pop();
      await tester.pumpAndSettle();
      expect(s.vetUnread('th_clinic'), 0);
    });

    testWidgets('AX5: title and preview reflow with nothing truncated', (
      tester,
    ) async {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 5))),
      );
      await tester.pumpWidget(
        AppScope(
          store: s,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
            child: CupertinoApp(
              theme: themeFor(AppPalette.light),
              home: const VetChatsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The title wraps fully instead of hiding behind an ellipsis.
      expect(tester.widget<Text>(find.text('Marco · Mochi')).maxLines, isNull);
      // The preview also wraps fully, full-width below the header.
      expect(
        tester
            .widget<Text>(
              find.text('Hi, is Mochi\u2019s vaccination slot still free?'),
            )
            .maxLines,
        isNull,
      );
    });

    testWidgets('search narrows the inbox to matching threads', (tester) async {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 5))),
      );
      await pumpInbox(tester, s);
      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'no-such-name',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching chats'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('vet replies never count as unread', () {
    // The vet's own sends (typed message + the simulated reply) must not
    // inflate the inbox badge: opening the thread and sending in it both
    // move the vet's read marker.
    testWidgets('sending as vet marks the thread read', (tester) async {
      await AuthStore.register(
        name: 'Dr. Vet',
        email: 'vet@carepaws.test',
        password: 'vetpass123',
        role: 'vet',
      );
      final s = _store();
      // signIn awaits a 420ms button-state delay: real async zone, or the
      // fake test clock deadlocks the wait.
      await tester.runAsync(() => s.signIn('vet@carepaws.test', 'vetpass123'));
      expect(s.shell, AppShell.vet);
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 5))),
      );
      expect(s.vetUnread('th_clinic'), 1);

      await tester.pumpWidget(
        AppScope(
          store: s,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: ChatThreadScreen(
              threadId: 'th_clinic',
              replyRole: StaffRole.vet,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'On it — bringing Mochi in tomorrow.',
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(s.vetUnread('th_clinic'), 0);
    });
  });
}
