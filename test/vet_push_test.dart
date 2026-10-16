import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carepaws/data/models.dart';
import 'package:carepaws/data/seed.dart';
import 'package:carepaws/services/ai_service.dart';
import 'package:carepaws/services/auth_store.dart';
import 'package:carepaws/services/vet_push_service.dart';
import 'package:carepaws/state/app_store.dart';

/// Task 8 — staff push alerts. Written before the implementation (RED first).
///
/// Pins the trigger points (queue-addition events, never polling), the
/// quiet-hours rule (outside clinic hours → batched morning digest, never a
/// 2 AM ping), and the role gate (customer-role devices never receive vet
/// alerts). Delivery itself is a stubbed seam — these tests assert on the
/// trigger/digest/role logic, not on OneSignal.
class _FailFast extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 401);
}

class _RecordingDelivery implements VetPushDelivery {
  final delivered = <VetAlert>[];
  final deliveredDigests = <List<VetAlert>>[];

  @override
  void deliver(VetAlert alert) => delivered.add(alert);

  @override
  void deliverDigest(List<VetAlert> items) =>
      deliveredDigests.add(List.of(items));
}

AppStore _store({VetPushDelivery? delivery}) {
  final s = AppStore(
    ai: AiService(client: _FailFast()),
    pushDelivery: delivery,
  );
  addTearDown(s.dispose);
  return s;
}

Future<AppStore> _vetStore({DateTime? now, VetPushDelivery? delivery}) async {
  expect(
    await AuthStore.register(
      name: 'Dr. Vet',
      email: 'pushvet@carepaws.test',
      password: 'vetpass123',
      role: 'vet',
    ),
    isNull,
  );
  final store = _store(delivery: delivery);
  if (now != null) store.now = now;
  expect(await store.signIn('pushvet@carepaws.test', 'vetpass123'), isTrue);
  expect(store.shell, AppShell.vet);
  // Registered accounts start with a clean slate — seed one pet so the
  // demand events have identifying info to carry.
  store.addPet(Seed.pets.first);
  return store;
}

/// Monday 2026-10-19 10:00 AM — inside clinic hours.
DateTime get _openTime => DateTime(2026, 10, 19, 10, 0);

/// Sunday 2026-10-18 02:00 AM — deep in quiet hours.
DateTime get _quietTime => DateTime(2026, 10, 18, 2, 0);

Appointment _request(AppStore store, {String id = 'pa1'}) => Appointment(
  id: id,
  petId: store.pets.first.id,
  serviceId: 'sv1',
  staffId: 'st1',
  start: DateTime(2026, 10, 20, 10, 0),
  durationMinutes: 30,
  status: ApptStatus.requestPending,
  price: 850,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('vet alert triggers (open hours)', () {
    test('new appointment request queues a vet device alert', () async {
      final delivery = _RecordingDelivery();
      final store = await _vetStore(now: _openTime, delivery: delivery);

      store.addAppointment(_request(store));

      expect(store.vetPush.sentImmediate, hasLength(1));
      final alert = store.vetPush.sentImmediate.single;
      expect(alert.kind, VetAlertKind.appointmentRequest);
      // Identifying info: pet name + customer, deep link to the queue item.
      expect(alert.body, contains(store.pets.first.name));
      expect(alert.body, contains(store.ownerFirstName));
      expect(alert.deepLink, contains('request-pa1'));
      // And the delivery seam actually got it.
      expect(delivery.delivered, hasLength(1));
      expect(delivery.delivered.single.id, alert.id);
    });

    test('customer reply in a thread queues a vet device alert', () async {
      final delivery = _RecordingDelivery();
      final store = await _vetStore(now: _openTime, delivery: delivery);

      store.pushMessage(
        ChatMessage(
          id: 'm1',
          threadId: 'th_clinic',
          author: ChatAuthor.vetAssistant,
          text: 'Is Milo due for his vaccine?',
          at: store.now,
          sentByMe: true,
        ),
      );

      expect(store.vetPush.sentImmediate, hasLength(1));
      final alert = store.vetPush.sentImmediate.single;
      expect(alert.kind, VetAlertKind.chatReply);
      expect(alert.title, contains(store.ownerFirstName));
      expect(alert.body, contains('Is Milo due for his vaccine?'));
      expect(alert.deepLink, contains('chat-th_clinic'));
      expect(delivery.delivered, hasLength(1));
    });

    test('customer-shared triage handoff queues an urgent alert', () async {
      final delivery = _RecordingDelivery();
      final store = await _vetStore(now: _openTime, delivery: delivery);
      final pet = store.pets.first;

      store.handOffToClinic(
        pet: pet,
        result: TriageResult(
          route: TriageRoute.book,
          title: 'Limping',
          summary: '${pet.name} is limping on his left hind paw.',
          urgency: 2,
        ),
      );

      // Exactly one alert: the handoff. The automatic staff thank-you reply
      // must not create a second one.
      expect(store.vetPush.sentImmediate, hasLength(1));
      final alert = store.vetPush.sentImmediate.single;
      expect(alert.kind, VetAlertKind.triageHandoff);
      expect(alert.priority, VetAlertPriority.urgent);
      expect(alert.body, contains(pet.name));
      expect(alert.deepLink, contains('handoff-'));
      expect(delivery.delivered, hasLength(1));
    });

    test('paid order queues a vet device alert', () async {
      final delivery = _RecordingDelivery();
      final store = await _vetStore(now: _openTime, delivery: delivery);

      store.addOrder(
        Order(
          id: 'po1',
          placedAt: store.now,
          lines: const [OrderLine('p1', 2, 150)],
          status: OrderStatus.paid,
          pickupCode: 'PC-9001',
          method: 'GCash',
        ),
      );

      expect(store.vetPush.sentImmediate, hasLength(1));
      final alert = store.vetPush.sentImmediate.single;
      expect(alert.kind, VetAlertKind.orderPlaced);
      expect(alert.title, contains('PC-9001'));
      expect(alert.deepLink, contains('order-po1'));
      expect(delivery.delivered, hasLength(1));
    });
  });

  group('trigger guards — no alert when nothing new lands', () {
    test('staff reply in a thread does not alert', () async {
      final store = await _vetStore(now: _openTime);
      store.pushMessage(
        ChatMessage(
          id: 'm2',
          threadId: 'th_clinic',
          author: ChatAuthor.vet,
          text: 'Thanks, see you tomorrow!',
          at: store.now,
        ),
      );
      expect(store.vetPush.sentImmediate, isEmpty);
      expect(store.vetPush.digest, isEmpty);
    });

    test('message in the AI thread does not alert the vet', () async {
      final store = await _vetStore(now: _openTime);
      store.pushMessage(
        ChatMessage(
          id: 'm3',
          threadId: 'th_ai',
          author: ChatAuthor.ai,
          text: 'Follow-up question',
          at: store.now,
          sentByMe: true,
        ),
      );
      expect(store.vetPush.sentImmediate, isEmpty);
      expect(store.vetPush.digest, isEmpty);
    });

    test('confirmed appointment (not a request) does not alert', () async {
      final store = await _vetStore(now: _openTime);
      store.addAppointment(
        Appointment(
          id: 'pa2',
          petId: store.pets.first.id,
          serviceId: 'sv1',
          staffId: 'st1',
          start: DateTime(2026, 10, 20, 10, 0),
          durationMinutes: 30,
          status: ApptStatus.confirmed,
          price: 850,
        ),
      );
      expect(store.vetPush.sentImmediate, isEmpty);
      expect(store.vetPush.digest, isEmpty);
    });

    test('unpaid order does not alert', () async {
      final store = await _vetStore(now: _openTime);
      store.addOrder(
        Order(
          id: 'po2',
          placedAt: store.now,
          lines: const [OrderLine('p1', 1, 150)],
          status: OrderStatus.pendingPayment,
          pickupCode: 'PC-9002',
          method: 'GCash',
        ),
      );
      expect(store.vetPush.sentImmediate, isEmpty);
      expect(store.vetPush.digest, isEmpty);
    });
  });

  group('quiet hours → morning digest', () {
    test('2 AM Sunday: no immediate alert; item lands in the digest', () async {
      final delivery = _RecordingDelivery();
      final store = await _vetStore(now: _quietTime, delivery: delivery);

      store.addAppointment(_request(store));

      // No 2 AM ping.
      expect(store.vetPush.sentImmediate, isEmpty);
      expect(delivery.delivered, isEmpty);
      // Batched for the morning instead.
      expect(store.vetPush.digest, hasLength(1));
      expect(store.vetPush.digest.single.kind, VetAlertKind.appointmentRequest);
    });

    test('digest is delivered once at clinic open, then cleared', () async {
      final delivery = _RecordingDelivery();
      final store = await _vetStore(now: _quietTime, delivery: delivery);

      store.addAppointment(_request(store, id: 'pa3'));
      store.pushMessage(
        ChatMessage(
          id: 'm4',
          threadId: 'th_clinic',
          author: ChatAuthor.vetAssistant,
          text: 'Midnight question',
          at: store.now,
          sentByMe: true,
        ),
      );
      expect(store.vetPush.digest, hasLength(2));

      // Still quiet at 6 AM — nothing goes out.
      store.now = DateTime(2026, 10, 19, 6, 0);
      store.vetPush.checkDigestDue();
      expect(delivery.deliveredDigests, isEmpty);
      expect(store.vetPush.digest, hasLength(2));

      // Clinic opens 9 AM Monday — one batched push, digest cleared.
      store.now = DateTime(2026, 10, 19, 9, 5);
      store.vetPush.checkDigestDue();
      expect(delivery.deliveredDigests, hasLength(1));
      expect(delivery.deliveredDigests.single, hasLength(2));
      expect(store.vetPush.digest, isEmpty);

      // A second check sends nothing — no duplicate digests.
      store.vetPush.checkDigestDue();
      expect(delivery.deliveredDigests, hasLength(1));
    });

    test(
      'urgent handoff during quiet hours still waits for the digest',
      () async {
        final delivery = _RecordingDelivery();
        final store = await _vetStore(now: _quietTime, delivery: delivery);

        store.handOffToClinic(
          pet: store.pets.first,
          result: TriageResult(
            route: TriageRoute.book,
            title: 'Limping',
            summary: '${store.pets.first.name} is limping.',
            urgency: 2,
          ),
        );

        // Urgent but not alarming at 2 AM: batched, priority preserved.
        expect(delivery.delivered, isEmpty);
        expect(store.vetPush.sentImmediate, isEmpty);
        expect(store.vetPush.digest, hasLength(1));
        expect(store.vetPush.digest.single.priority, VetAlertPriority.urgent);
      },
    );
  });

  group('role gate', () {
    test('customer-role device never receives vet alerts', () async {
      final delivery = _RecordingDelivery();
      // Fresh store = customer shell (no vet signed in).
      final store = _store(delivery: delivery);
      expect(store.shell, AppShell.customer);
      store.now = _openTime;

      store.addAppointment(_request(store));
      store.pushMessage(
        ChatMessage(
          id: 'm5',
          threadId: 'th_clinic',
          author: ChatAuthor.vetAssistant,
          text: 'A customer message',
          at: store.now,
          sentByMe: true,
        ),
      );
      store.addOrder(
        Order(
          id: 'po3',
          placedAt: store.now,
          lines: const [OrderLine('p1', 1, 150)],
          status: OrderStatus.paid,
          pickupCode: 'PC-9003',
          method: 'GCash',
        ),
      );

      expect(store.vetPush.sentImmediate, isEmpty);
      expect(store.vetPush.digest, isEmpty);
      expect(delivery.delivered, isEmpty);
      expect(delivery.deliveredDigests, isEmpty);
    });
  });
}
