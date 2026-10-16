import 'package:flutter/foundation.dart';

import '../data/clinic.dart';

/// What kind of new demand landed in the vet queue.
enum VetAlertKind { appointmentRequest, chatReply, triageHandoff, orderPlaced }

/// Triage handoffs are urgent (a sick pet's health check was shared);
/// everything else is normal priority. Urgent never means alarming — alert
/// copy stays informative and calm (see the tone rule on [VetAlert]).
enum VetAlertPriority { normal, urgent }

/// A single staff push alert for the vet portal.
///
/// Tone rule (standing): informative, never alarming. Titles name the demand
/// type; bodies carry identifying info (pet name, customer) and the deep
/// link opens the matching item in the vet Queue screen. The deep-link ids
/// mirror the [VetQueueItem] ids built by `buildVetQueue`
/// (`lib/screens/vet/queue_screen.dart`) — keep them in sync:
/// `request-<appointmentId>`, `chat-<threadId>`, `handoff-<messageId>`,
/// `order-<orderId>`.
@immutable
class VetAlert {
  const VetAlert._({
    required this.id,
    required this.kind,
    required this.priority,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.at,
  });

  /// [id] doubles as the dedupe key and the queue item id.
  final String id;
  final VetAlertKind kind;
  final VetAlertPriority priority;
  final String title;
  final String body;
  final String deepLink;
  final DateTime at;

  factory VetAlert.appointmentRequest({
    required String appointmentId,
    required String petName,
    required String serviceName,
    required String customerName,
    required DateTime at,
  }) => VetAlert._(
    id: 'request-$appointmentId',
    kind: VetAlertKind.appointmentRequest,
    priority: VetAlertPriority.normal,
    title: 'New appointment request',
    body: '$petName · $serviceName — $customerName',
    deepLink: 'carepaws://vet/queue/request-$appointmentId',
    at: at,
  );

  factory VetAlert.chatReply({
    required String messageId,
    required String threadId,
    required String customerName,
    required String snippet,
    required DateTime at,
  }) => VetAlert._(
    id: 'chatreply-$messageId',
    kind: VetAlertKind.chatReply,
    priority: VetAlertPriority.normal,
    title: 'New message from $customerName',
    body: snippet,
    deepLink: 'carepaws://vet/queue/chat-$threadId',
    at: at,
  );

  factory VetAlert.triageHandoff({
    required String messageId,
    required String petName,
    required String summary,
    required DateTime at,
  }) => VetAlert._(
    id: 'handoff-$messageId',
    kind: VetAlertKind.triageHandoff,
    priority: VetAlertPriority.urgent,
    title: 'Health check shared — $petName',
    body: '$summary — review in the queue',
    deepLink: 'carepaws://vet/queue/handoff-$messageId',
    at: at,
  );

  factory VetAlert.orderPlaced({
    required String orderId,
    required String pickupCode,
    required int itemCount,
    required String customerName,
    required DateTime at,
  }) => VetAlert._(
    id: 'order-$orderId',
    kind: VetAlertKind.orderPlaced,
    priority: VetAlertPriority.normal,
    title: 'New shop order $pickupCode',
    body: '$itemCount item${itemCount == 1 ? '' : 's'} · $customerName',
    deepLink: 'carepaws://vet/queue/order-$orderId',
    at: at,
  );
}

/// Last-mile transport for staff push alerts.
///
/// STUBBED — no OneSignal wiring exists in this client yet: device tokens
/// and player IDs are backend-dependent (a Supabase edge function calling
/// the OneSignal REST API). The trigger logic, role gate, quiet-hours rule
/// and morning-digest batching are all implemented and unit-tested on this
/// seam; only the final transport is stubbed. The OneSignal integration
/// lands here — do not build a second push system alongside it.
abstract class VetPushDelivery {
  /// Sends one immediate push.
  void deliver(VetAlert alert);

  /// Sends one batched push covering everything accumulated overnight.
  void deliverDigest(List<VetAlert> items);
}

/// The default delivery: a no-op. Real delivery is wired by passing a
/// [VetPushDelivery] into the [AppStore] constructor.
class _NoopVetPushDelivery implements VetPushDelivery {
  const _NoopVetPushDelivery();

  @override
  void deliver(VetAlert alert) {}

  @override
  void deliverDigest(List<VetAlert> items) {}
}

/// Raises staff push alerts for new vet-queue demand.
///
/// Triggers are hooked where queue items are created (appointment request
/// added, customer chat reply, triage handoff shared, order placed) — never
/// by polling the queue. The rules, in order:
///
/// 1. Role gate: alerts only target vet-role devices. A customer-role device
///    (or a signed-out one) drops everything, immediately and from digests.
/// 2. Quiet hours: while [Clinic.isOpenNow] is false, nothing pings — the
///    alert accumulates into the morning digest instead.
/// 3. Dedupe: one alert per queue item ([VetAlert.id]); repeats are dropped.
///
/// The digest flushes as a single batched push the next time the clinic is
/// open — [checkDigestDue] runs on the app clock and on vet sign-in.
class VetPushService extends ChangeNotifier {
  VetPushService({
    required this._clock,
    required this._isVetDevice,
    VetPushDelivery? delivery,
  }) : _delivery = delivery ?? const _NoopVetPushDelivery();

  final DateTime Function() _clock;
  final bool Function() _isVetDevice;
  final VetPushDelivery _delivery;

  final List<VetAlert> _sentImmediate = [];
  final List<VetAlert> _digest = [];
  final List<List<VetAlert>> _flushedDigests = [];

  /// Alerts delivered immediately (open hours), newest last.
  List<VetAlert> get sentImmediate => List.unmodifiable(_sentImmediate);

  /// Alerts batched for the morning digest, newest last.
  List<VetAlert> get digest => List.unmodifiable(_digest);

  /// Digest batches already flushed, for tests and diagnostics.
  List<List<VetAlert>> get flushedDigests => List.unmodifiable(_flushedDigests);

  /// Raises an alert for new vet-queue demand, applying the role gate,
  /// quiet-hours rule and dedupe.
  void raise(VetAlert alert) {
    if (!_isVetDevice()) return;
    if (_seen(alert.id)) return;
    if (Clinic.isOpenNow(_clock())) {
      _delivery.deliver(alert);
      _sentImmediate.add(alert);
    } else {
      _digest.add(alert);
    }
    notifyListeners();
  }

  /// Sends the accumulated digest as one batched push once the clinic is
  /// open. Safe to call any time — a no-op while quiet or when empty.
  void checkDigestDue() {
    if (_digest.isEmpty) return;
    if (!Clinic.isOpenNow(_clock())) return;
    final batch = List<VetAlert>.of(_digest);
    _digest.clear();
    _delivery.deliverDigest(batch);
    _flushedDigests.add(batch);
    notifyListeners();
  }

  bool _seen(String id) =>
      _sentImmediate.any((a) => a.id == id) || _digest.any((a) => a.id == id);
}
