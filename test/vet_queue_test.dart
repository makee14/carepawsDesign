import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/appointments/appointment_detail_screen.dart';
import 'package:carepaws/screens/chat_thread_screen.dart';
import 'package:carepaws/screens/shop/orders_screen.dart';
import 'package:carepaws/screens/vet/queue_screen.dart';
import 'package:carepaws/screens/vet/widgets/queue_card.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task 3 — vet work queue (triage work queue). Written before the
/// implementation (RED first).
///
/// Pins the spec: the queue is sorted by urgency —
/// user-shared triage handoffs (sick) > appointment requests (today) >
/// waiting chats > orders awaiting prep. Triage results that the customer
/// never opted to share must not appear at all; sharing is the act of
/// handing the result to the clinic (a [ChatKind.triageHandoff] message in
/// the clinic thread). Tapping a card opens the underlying item.
DateTime _now() => DateTime(2026, 10, 17, 9, 30);

AppStore _store() {
  final s = AppStore(now: _now());
  addTearDown(s.dispose);
  return s;
}

Appointment _request(
  AppStore s, {
  required String petId,
  required DateTime start,
}) => Appointment(
  id: 'qr-${start.millisecondsSinceEpoch}',
  petId: petId,
  serviceId: 'sv1',
  staffId: 's1',
  start: start,
  durationMinutes: 30,
  status: ApptStatus.requestPending,
  price: 850,
);

ChatMessage _customerMessage(AppStore s, {required DateTime at}) => ChatMessage(
  id: 'w${at.microsecondsSinceEpoch}',
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('queue ordering (urgency)', () {
    test('triage handoffs sort above appointment requests', () {
      final s = _store();
      _shareTriage(s);
      s.addAppointment(
        _request(s, petId: 'p2', start: _now().add(const Duration(hours: 2))),
      );
      final kinds = buildVetQueue(s).map((i) => i.kind).toList();
      expect(
        kinds.indexOf(VetQueueKind.triageHandoff),
        lessThan(kinds.indexOf(VetQueueKind.appointmentRequest)),
      );
    });

    test('appointment requests sort above waiting chats', () {
      final s = _store();
      s.addAppointment(
        _request(s, petId: 'p2', start: _now().add(const Duration(hours: 2))),
      );
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 40))),
      );
      final kinds = buildVetQueue(s).map((i) => i.kind).toList();
      expect(
        kinds.indexOf(VetQueueKind.appointmentRequest),
        lessThan(kinds.indexOf(VetQueueKind.waitingChat)),
      );
    });

    test('waiting chats sort above orders awaiting prep', () {
      final s = _store();
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 40))),
      );
      // Seed order o1 is paid (awaiting prep).
      final kinds = buildVetQueue(s).map((i) => i.kind).toList();
      expect(kinds, contains(VetQueueKind.order));
      expect(
        kinds.indexOf(VetQueueKind.waitingChat),
        lessThan(kinds.indexOf(VetQueueKind.order)),
      );
    });

    test('appointment requests today sort before future ones', () {
      final s = _store();
      final future = _request(
        s,
        petId: 'p2',
        start: _now().add(const Duration(days: 3)),
      );
      final today = _request(
        s,
        petId: 'p1',
        start: _now().add(const Duration(hours: 2)),
      );
      s.addAppointment(future);
      s.addAppointment(today);
      final requests = buildVetQueue(s)
          .where((i) => i.kind == VetQueueKind.appointmentRequest)
          .toList();
      expect(requests.map((i) => i.appointmentId), [today.id, future.id]);
    });

    test('unshared triage results never enter the queue', () {
      // No handOffToClinic call: the customer never opted to share, so no
      // triage-handoff message exists and nothing triage-shaped may appear.
      final s = _store();
      expect(
        buildVetQueue(s).where((i) => i.kind == VetQueueKind.triageHandoff),
        isEmpty,
      );
    });

    test('threads whose last message is from staff are not waiting chats', () {
      // Seed clinic thread ends with a staff message (+ a system auto-reply):
      // nothing for staff to reply to.
      final s = _store();
      expect(
        buildVetQueue(s).where((i) => i.kind == VetQueueKind.waitingChat),
        isEmpty,
      );
    });

    test('a thread shared as a handoff is not duplicated as a waiting chat', () {
      final s = _store();
      _shareTriage(s);
      // The customer writes again AFTER the handoff + auto-reply: the thread's
      // last message is now the customer's, so without the dedupe it would
      // surface twice — once as a handoff, once as a waiting chat.
      s.pushMessage(
        _customerMessage(s, at: _now().add(const Duration(minutes: 5))),
      );
      final items = buildVetQueue(s);
      final clinicItems = items
          .where((i) => i.threadId == 'th_clinic')
          .toList();
      expect(clinicItems, hasLength(1));
      expect(clinicItems.single.kind, VetQueueKind.triageHandoff);
    });

    test('orders awaiting prep are paid orders only', () {
      final s = _store();
      s.orders = [
        ...s.orders,
        s.orders.first.copyWith(status: OrderStatus.pickedUp),
      ];
      final orders = buildVetQueue(s)
          .where((i) => i.kind == VetQueueKind.order)
          .toList();
      expect(orders, hasLength(1));
      expect(orders.single.orderId, 'o1');
    });
  });

  group('queue cards', () {
    // NOTE: one clinic thread exists, so a store can hold a triage handoff
    // XOR a waiting chat for it — never both (the handoff wins). Stores below
    // are built per scenario.
    AppStore handoffRequestOrderStore() {
      final s = _store();
      _shareTriage(s);
      s.addAppointment(
        _request(s, petId: 'p2', start: _now().add(const Duration(hours: 2))),
      );
      return s;
    }

    AppStore waitingChatStore() {
      final s = _store();
      s.orders = const [];
      s.pushMessage(
        _customerMessage(s, at: _now().subtract(const Duration(minutes: 40))),
      );
      return s;
    }

    Future<void> pumpQueue(WidgetTester tester, AppStore store) async {
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const QueueScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('each item type renders a card with identifying info', (
      tester,
    ) async {
      await pumpQueue(tester, handoffRequestOrderStore());
      expect(tester.takeException(), isNull);
      expect(find.byType(QueueCard), findsNWidgets(3));
      // Triage handoff: pet name.
      expect(find.text('Biscuit', skipOffstage: false), findsWidgets);
      // Appointment request: pet name + service.
      expect(find.textContaining('Mochi', skipOffstage: false), findsWidgets);
      // Order: pickup code on the card.
      expect(find.textContaining('PC-4820', skipOffstage: false), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a waiting chat renders its own card', (tester) async {
      await pumpQueue(tester, waitingChatStore());
      expect(find.byType(QueueCard), findsOneWidget);
      expect(find.text('Clinic team', skipOffstage: false), findsOneWidget);
      // The customer's own words identify the chat.
      expect(
        find.textContaining('vaccination slot', skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping an appointment card opens the appointment detail', (
      tester,
    ) async {
      await pumpQueue(tester, handoffRequestOrderStore());
      final card = find.ancestor(
        of: find.textContaining('Mochi'),
        matching: find.byType(QueueCard),
      );
      await tester.ensureVisible(card.first);
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a triage handoff card opens the chat thread', (
      tester,
    ) async {
      await pumpQueue(tester, handoffRequestOrderStore());
      final card = find.ancestor(
        of: find.text('Biscuit'),
        matching: find.byType(QueueCard),
      );
      await tester.ensureVisible(card.first);
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      expect(find.byType(ChatThreadScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a chat card opens the chat thread', (tester) async {
      await pumpQueue(tester, waitingChatStore());
      final card = find.ancestor(
        of: find.text('Clinic team'),
        matching: find.byType(QueueCard),
      );
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(ChatThreadScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping an order card opens the orders screen', (
      tester,
    ) async {
      await pumpQueue(tester, handoffRequestOrderStore());
      final card = find.ancestor(
        of: find.textContaining('PC-4820'),
        matching: find.byType(QueueCard),
      );
      await tester.ensureVisible(card.first);
      await tester.tap(card.first);
      await tester.pumpAndSettle();
      expect(find.byType(OrdersScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty queue shows the all-caught-up state', (tester) async {
      final s = _store();
      s.orders = const [];
      // Seed data holds no request-pending appointments and no waiting chats,
      // so emptying the orders empties the whole queue.
      await pumpQueue(tester, s);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.byType(QueueCard), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
