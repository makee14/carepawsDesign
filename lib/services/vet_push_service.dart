import 'package:flutter/foundation.dart';

import '../data/clinic.dart';
import 'vet_push_api.dart';

export 'vet_push_api.dart';

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
class VetPushService extends ChangeNotifier implements VetPush {
  VetPushService(
    DateTime Function() clock,
    bool Function() isVetDevice, {
    VetPushDelivery? delivery,
  }) : _clock = clock,
       _isVetDevice = isVetDevice,
       _delivery = delivery ?? const _NoopVetPushDelivery();

  final DateTime Function() _clock;
  final bool Function() _isVetDevice;
  final VetPushDelivery _delivery;

  final List<VetAlert> _sentImmediate = [];
  final List<VetAlert> _digest = [];
  final List<List<VetAlert>> _flushedDigests = [];

  /// Alerts delivered immediately (open hours), newest last.
  @override
  List<VetAlert> get sentImmediate => List.unmodifiable(_sentImmediate);

  /// Alerts batched for the morning digest, newest last.
  @override
  List<VetAlert> get digest => List.unmodifiable(_digest);

  /// Digest batches already flushed, for tests and diagnostics.
  List<List<VetAlert>> get flushedDigests => List.unmodifiable(_flushedDigests);

  /// Raises an alert for new vet-queue demand, applying the role gate,
  /// quiet-hours rule and dedupe.
  @override
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
  @override
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
