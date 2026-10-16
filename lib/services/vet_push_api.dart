import 'package:flutter/foundation.dart';

/// Flavor-neutral vet-push API.
///
/// The alert data types live here so `lib/state/app_store.dart` — reachable
/// from the customer entry `lib/main.dart` — can raise alerts without
/// importing `vet_push_service.dart`. The service implementation itself
/// ([VetPushService]) is vet-only: it is constructed behind the vet entry
/// point's `kVetFlavor`-gated factory, so tree-shaking drops it from the
/// customer binary.

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

/// The vet push service surface used by [AppStore].
///
/// Implemented by the vet-only [VetPushService]; the customer flavor gets a
/// no-op. An interface (not the concrete service) so the store — reachable
/// from the customer entry chain — never imports `vet_push_service.dart`.
abstract interface class VetPush {
  /// Raises an alert for new vet-queue demand.
  void raise(VetAlert alert);

  /// Alerts delivered immediately (open hours), newest last.
  List<VetAlert> get sentImmediate;

  /// Alerts batched for the morning digest, newest last.
  List<VetAlert> get digest;

  /// Sends the accumulated digest as one batched push once the clinic is
  /// open. Safe to call any time — a no-op while quiet or when empty.
  void checkDigestDue();

  void dispose();
}
