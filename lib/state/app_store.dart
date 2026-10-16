import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../data/models.dart';
import '../data/seed.dart';
import '../data/clinic.dart';
import '../design/theme.dart' show ThemeMode;
import '../services/ai_service.dart';
import '../services/auth_store.dart';
import '../services/dataset_store.dart';
import '../services/photo_store.dart';
import '../services/settings_store.dart';
import '../services/staff_replies.dart';
import '../services/vet_push_api.dart';
import 'profile_store.dart';

/// Which shell the signed-in account gets after auth.
///
/// Exactly two roles exist — customer and vet. No staff sub-roles in the
/// portal (the `StaffRole` enum stays in the data model for service
/// assignment only; it is never used for portal gating). Sourced from the
/// login: the local [AuthStore] role field now, `profiles.role` when the
/// backend lands.
///
/// Invariant: [AppStore.shell] is `vet` only while a vet is signed in — a
/// fresh store and a signed-out store always read `customer`.
enum AppShell { customer, vet }

/// Builds the vet push service for an [AppStore].
///
/// Provided by the vet entry point (and tests). The customer entry chain
/// never provides one, so the customer build never imports
/// `vet_push_service.dart` and tree-shaking drops it from the customer APK.
typedef VetPushFactory = VetPush Function(
  AppStore store,
  VetPushDelivery? delivery,
);

/// No-op [VetPush] for the customer flavor: no factory is installed there,
/// so the alert triggers are dead ends that cost nothing.
class _NoopVetPush implements VetPush {
  const _NoopVetPush();

  @override
  void raise(VetAlert alert) {}

  @override
  List<VetAlert> get sentImmediate => const [];

  @override
  List<VetAlert> get digest => const [];

  @override
  void checkDigestDue() {}

  @override
  void dispose() {}
}

/// Single source of truth for the whole app. A lightweight ChangeNotifier is
/// enough here — the prototype has no need for a heavier state package.
class AppStore extends ChangeNotifier {
  AppStore({
    AiService? ai,
    DateTime? now,
    VetPushDelivery? pushDelivery,
    VetPushFactory? vetPushFactory,
  }) : ai = ai ?? AiService(),
       _now = now ?? DateTime.now() {
    // The real VetPushService is instantiated behind the vet entry point's
    // kVetFlavor-gated factory — never from the customer entry chain.
    vetPush = vetPushFactory?.call(this, pushDelivery) ?? const _NoopVetPush();
  }

  final AiService ai;

  /// Staff push alerts (Task 8): trigger + quiet-hours digest logic with a
  /// stubbed delivery seam. The real service ([VetPushService], vet flavor
  /// only) reads [shell] for its role gate, so alerts only ever target
  /// vet-role devices; the customer flavor gets a no-op.
  late final VetPush vetPush;

  DateTime _now;
  DateTime get now => _now;
  set now(DateTime v) {
    _now = v;
    notifyListeners();
  }

  Timer? _clock;

  /// Starts the wall clock: `now` re-reads the device time every 30s so live
  /// countdowns, open/closed state and the upcoming/past partition stay
  /// current without user interaction. Called once from `main()`; tests drive
  /// time with the [now] setter instead, so the timer never leaks into the test
  /// harness (a pending periodic timer fails `testWidgets` teardown).
  void startClock() {
    _clock ??= Timer.periodic(const Duration(seconds: 30), (_) {
      _now = DateTime.now();
      // Overnight digest flushes once the clinic is open again.
      vetPush.checkDigestDue();
      notifyListeners();
    });
  }

  /// Test seam / shutdown hook.
  void stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  @override
  void dispose() {
    stopClock();
    vetPush.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- app state
  bool get notificationsAsked => _notificationsAsked;
  bool _notificationsAsked = false;

  String language = 'English';

  /// Appearance preference. Defaults to [ThemeMode.system] so the app follows
  /// the OS out of the box — the same default iOS Settings uses. An explicit
  /// Light or Dark choice overrides it and is persisted.
  ThemeMode themeMode = ThemeMode.system;

  /// Convenience for the Appearance rows, which only ever describe an explicit
  /// choice. Under [ThemeMode.system] neither light nor dark is "selected".
  bool get darkMode => themeMode == ThemeMode.dark;
  bool get lightMode => themeMode == ThemeMode.light;

  bool reduceMotionOverride = false;

  /// The first-launch flow (splash → onboarding → register → Home) has
  /// completed. The single source of truth for launch routing; persisted.
  /// Replayable from Settings → Help, which shows the tour on demand without
  /// touching this flag.
  bool onboardingCompleted = false;

  List<Pet> pets = Seed.pets;
  List<Appointment> appointments = Seed.appointments;
  List<Product> products = Seed.products;
  List<Reminder> reminders = Seed.reminders;
  List<Order> orders = Seed.orders;
  List<Prescription> prescriptions = Seed.prescriptions;
  List<AppNotification> notifications = Seed.notifications;
  List<ChatMessage> messages = Seed.messages;
  List<CartLine> cart = const [];

  /// Completed AI health checks, newest last. Per-account persisted.
  List<HealthCheckResult> healthResults = const [];

  /// Products the user asked to be notified about (out-of-stock flow).
  final Set<String> notifyMe = {};

  int _tab = 0;
  int get tab => _tab;
  set tab(int v) {
    if (_tab == v) return;
    _tab = v;
    notifyListeners();
  }

  // ------------------------------------------------------- owner profile
  /// Display name: the name saved on Edit profile when signed in with an
  /// account, otherwise the registered account's name, otherwise the seeded
  /// owner name (demo account).
  String get ownerName => _profileName ?? accountName ?? Seed.ownerName;

  /// Phone number saved on Edit profile. Empty until the owner saves one —
  /// the old build showed a hardcoded seed contact here instead.
  String get ownerPhone => _profilePhone;

  /// Email of the signed-in account, normalized to lowercase. Empty when
  /// signed out.
  String get ownerEmail => accountEmail ?? '';

  String? _profileName;
  String _profilePhone = '';

  /// Loads the saved name/phone for the signed-in account. Called after a
  /// successful sign-in; without it, edits from a previous session would
  /// silently revert to the registration/seed values.
  Future<void> _loadOwnerProfile() async {
    final email = accountEmail;
    if (email == null) {
      _profileName = null;
      _profilePhone = '';
      return;
    }
    final saved = await ProfileStore.read(email);
    _profileName = saved.name.isEmpty ? null : saved.name;
    _profilePhone = saved.phone;
  }

  /// Validates and saves the editable profile. Returns null on success, or a
  /// map of field → message for inline errors. The email is the account key
  /// and is never edited here.
  Future<Map<ProfileField, String>?> saveOwnerProfile({
    required String name,
    required String phone,
  }) async {
    final errors = <ProfileField, String>{};
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      errors[ProfileField.name] = 'Please enter your name.';
    }
    final cleanPhone = phone.trim();
    if (cleanPhone.isNotEmpty && !_looksLikePhone(cleanPhone)) {
      errors[ProfileField.phone] = 'That phone number does not look right.';
    }
    if (errors.isNotEmpty) return errors;

    _profileName = cleanName;
    _profilePhone = cleanPhone;
    final email = accountEmail;
    if (email != null) {
      await ProfileStore.write(
        email: email,
        name: cleanName,
        phone: cleanPhone,
      );
    }
    notifyListeners();
    return null;
  }

  /// Lenient on purpose: international prefixes, spaces, dashes, parentheses
  /// are all fine — the only requirement is at least 7 digits.
  static bool _looksLikePhone(String s) {
    if (!RegExp(r'^[+()\-. \d]+$').hasMatch(s)) return false;
    return RegExp(r'\d').allMatches(s).length >= 7;
  }

  // ------------------------------------------------------------- accessors
  /// First name for conversational copy. Empty when the profile has no name —
  /// callers use a plain greeting instead of a hardcoded name.
  String get ownerFirstName {
    final n = ownerName.trim();
    return n.isEmpty ? '' : n.split(RegExp(r'\s+')).first;
  }

  Appointment? get nextAppointment {
    final up = upcomingAppointments;
    return up.isEmpty ? null : up.first;
  }

  /// Soonest first — the home appointment card and the Appointments list
  /// rely on the same ordering. Visits whose pet is no longer on the account
  /// are skipped, so removing a pet (or the whole account) can never leave
  /// a dangling reference on screen.
  List<Appointment> get upcomingAppointments =>
      (appointments
            .where(
              (a) =>
                  a.status.isActive &&
                  a.end.isAfter(now) &&
                  pet(a.petId) != null,
            )
            .toList())
        ..sort((a, b) => a.start.compareTo(b.start));

  /// Alias kept for existing callers.
  List<Appointment> get upcoming => upcomingAppointments;

  List<Appointment> get past =>
      appointments
          .where((a) => !a.status.isActive || a.end.isBefore(now))
          .toList()
        ..sort((a, b) => b.start.compareTo(a.start));

  Pet? pet(String id) => pets.where((p) => p.id == id).firstOrNull;

  Appointment? appt(String id) =>
      appointments.where((a) => a.id == id).firstOrNull;

  Appointment? apptForProduct(String productId) =>
      appointments.where((a) => a.petId == 'p1').firstOrNull;

  Staff staffOf(String id) => Seed.staff.firstWhere((s) => s.id == id);

  Service serviceOf(String id) => Seed.service(id);

  /// All bookable services — used by search.
  List<Service> get servicesForSearch => Seed.services;

  Product productOf(String id) => Seed.products.firstWhere((p) => p.id == id);

  int get unreadNotifications => notifications.where((n) => !n.read).length;

  /// The human team keeps the same hours as the front desk.
  bool staffOnline() => Clinic.isOpenNow(now);

  /// Response-time note shown when the human team is offline.
  String? get offlineNote {
    if (staffOnline()) return null;
    final o = Clinic.nextOpening(now);
    final today = DateTime(now.year, now.month, now.day);
    final sameDay =
        o.year == today.year && o.month == today.month && o.day == today.day;
    final when = sameDay ? 'today' : Clinic.weekdayName(o.weekday);
    return 'The clinic team is offline until ${Clinic.openTimeLabel} $when.';
  }

  // ----------------------------------------------------------------- pets
  int get petCount => pets.length;

  void addPet(Pet p) {
    pets = [p, ...pets];
    if (p.hasPhoto) PhotoStore.save(PhotoStore.petKey(p.id), p.photo!);
    _savePets();
    notifyListeners();
  }

  /// Replaces a pet in place, keeping its identity, timeline and documents.
  /// Used by the pet editor — only the editable fields change.
  void updatePet(Pet updated) {
    pets = pets.map((p) => p.id == updated.id ? updated : p).toList();
    if (updated.hasPhoto) {
      PhotoStore.save(PhotoStore.petKey(updated.id), updated.photo!);
    } else {
      PhotoStore.remove(PhotoStore.petKey(updated.id));
    }
    _savePets();
    notifyListeners();
  }

  /// Sets or clears one pet's portrait. Passing null restores the generated art.
  Future<void> setPetPhoto(String petId, Uint8List? bytes) async {
    pets = pets.map((p) => p.id == petId ? _withPhoto(p, bytes) : p).toList();
    if (bytes == null) {
      await PhotoStore.remove(PhotoStore.petKey(petId));
    } else {
      await PhotoStore.save(PhotoStore.petKey(petId), bytes);
    }
    notifyListeners();
  }

  /// The owner avatar. Null falls back to initials.
  Uint8List? ownerPhoto;

  bool get hasOwnerPhoto => ownerPhoto != null && ownerPhoto!.isNotEmpty;

  Future<void> setOwnerPhoto(Uint8List? bytes) async {
    ownerPhoto = bytes;
    if (bytes == null) {
      await PhotoStore.remove(PhotoStore.ownerKey);
    } else {
      await PhotoStore.save(PhotoStore.ownerKey, bytes);
    }
    notifyListeners();
  }

  static Pet _withPhoto(Pet p, Uint8List? bytes) => Pet(
    id: p.id,
    name: p.name,
    species: p.species,
    breed: p.breed,
    sex: p.sex,
    birthDate: p.birthDate,
    weightKg: p.weightKg,
    heightCm: p.heightCm,
    lengthCm: p.lengthCm,
    color: p.color,
    microchip: p.microchip,
    allergies: p.allergies,
    vitals: p.vitals,
    timeline: p.timeline,
    docs: p.docs,
    photo: bytes,
  );

  /// Rehydrates saved portraits. Called once at startup; the app renders
  /// generated art until this finishes, so it never blocks the first frame.
  Future<void> loadPhotos() async {
    ownerPhoto = await PhotoStore.load(PhotoStore.ownerKey);
    final loaded = <Pet>[];
    for (final p in pets) {
      final bytes = await PhotoStore.load(PhotoStore.petKey(p.id));
      loaded.add(bytes == null ? p : _withPhoto(p, bytes));
    }
    pets = loaded;
    notifyListeners();
  }

  void removePet(String id) {
    pets = pets.where((p) => p.id != id).toList();
    PhotoStore.remove(PhotoStore.petKey(id));
    _savePets();
    notifyListeners();
  }

  /// Empties the pet list — used by the zero-pet empty state and by account
  /// data deletion on the privacy screen.
  void clearPets() {
    pets = const [];
    _savePets();
    notifyListeners();
  }

  // --------------------------------------------------------- notifications
  void markNotificationsRead() {
    notifications = notifications.map((n) => n.copyWith(read: true)).toList();
    _saveNotifications();
    notifyListeners();
  }

  // ------------------------------------------------------------- reminders
  /// Returns true the first time a reminder is switched on, so the caller can
  /// present the in-context notification permission sheet.
  bool toggleReminder(String id, bool value) {
    var firstOn = false;
    reminders = reminders.map((r) {
      if (r.id != id) return r;
      if (value && !r.on && !_notificationsAsked) firstOn = true;
      return r.copyWith(on: value);
    }).toList();
    _saveReminders();
    notifyListeners();
    return firstOn;
  }

  void setNotificationsAsked(bool v) {
    _notificationsAsked = v;
    notifyListeners();
  }

  bool reminderOn(ReminderKind k) =>
      reminders.where((r) => r.kind == k).fold(false, (a, b) => a || b.on);

  // ---------------------------------------------------------- appointments
  void addAppointment(Appointment a) {
    appointments = [a, ...appointments];
    _saveAppointments();
    // New demand for the vet queue → staff push alert (role-gated, with the
    // quiet-hours digest rule, inside the service).
    if (a.status == ApptStatus.requestPending) {
      vetPush.raise(
        VetAlert.appointmentRequest(
          appointmentId: a.id,
          petName: pet(a.petId)?.name ?? 'A pet',
          serviceName: serviceOf(a.serviceId).name,
          customerName: ownerFirstName,
          at: now,
        ),
      );
    }
    notifyListeners();
  }

  void updateAppointment(String id, Appointment Function(Appointment) f) {
    appointments = appointments.map((a) => a.id == id ? f(a) : a).toList();
    _saveAppointments();
    notifyListeners();
  }

  // ------------------------------------------------- vet schedule actions
  //
  // The allowed status chain, enforced here — not just in the UI — so no
  // caller can put an appointment in an impossible state:
  //   requestPending -> confirmed | cancelled
  //   confirmed/booked -> beingGroomed (grooming) | completed | cancelled
  //   beingGroomed -> readyForPickup | cancelled
  //   readyForPickup -> completed | cancelled
  //   completed/cancelled -> terminal; nothing leads back out.
  // Every method returns false and changes nothing when the transition is
  // illegal (unknown id, wrong state, or out-of-hours reschedule).

  /// requestPending -> confirmed. One-shot: any other state is rejected.
  bool confirmAppointment(String id) {
    final a = appt(id);
    if (a == null || a.status != ApptStatus.requestPending) return false;
    updateAppointment(id, (x) => _copy(x, status: ApptStatus.confirmed));
    return true;
  }

  /// One step along the chain. Grooming visits move through the grooming
  /// states; every other service goes straight to completed.
  bool advanceAppointment(String id) {
    final a = appt(id);
    if (a == null) return false;
    final next = switch (a.status) {
      ApptStatus.confirmed || ApptStatus.booked =>
        serviceOf(a.serviceId).grooming
            ? ApptStatus.beingGroomed
            : ApptStatus.completed,
      ApptStatus.beingGroomed => ApptStatus.readyForPickup,
      ApptStatus.readyForPickup => ApptStatus.completed,
      _ => null,
    };
    if (next == null) return false;
    updateAppointment(id, (x) => _copy(x, status: next));
    return true;
  }

  /// Marks an active appointment cancelled. Terminal and one-way: there is no
  /// restore path, so cancelling a completed/cancelled appointment is
  /// rejected rather than silently re-applied.
  bool cancelAppointment(String id) {
    final a = appt(id);
    if (a == null || !a.status.isActive) return false;
    updateAppointment(id, (x) => _copy(x, status: ApptStatus.cancelled));
    return true;
  }

  /// Moves an active appointment to [start]. The slot must sit inside clinic
  /// hours ([Clinic]: Mon–Sat, opening hour to closing hour, the visit ending
  /// by close) and must not be in the past.
  bool rescheduleAppointment(String id, DateTime start) {
    final a = appt(id);
    if (a == null || !a.status.isActive) return false;
    if (start.weekday == DateTime.sunday) return false;
    final open = DateTime(start.year, start.month, start.day, Clinic.openHour);
    final close = DateTime(
      start.year,
      start.month,
      start.day,
      Clinic.closeHour,
    );
    if (start.isBefore(open)) return false;
    if (start.add(Duration(minutes: a.durationMinutes)).isAfter(close)) {
      return false;
    }
    if (start.isBefore(now)) return false;
    updateAppointment(id, (x) => _copy(x, start: start));
    return true;
  }

  /// Reassigns an active appointment to another staff member.
  bool assignStaff(String appointmentId, String staffId) {
    final a = appt(appointmentId);
    if (a == null || !a.status.isActive) return false;
    if (!Seed.staff.any((s) => s.id == staffId)) return false;
    updateAppointment(appointmentId, (x) => _copy(x, staffId: staffId));
    return true;
  }

  static Appointment _copy(
    Appointment a, {
    DateTime? start,
    int? durationMinutes,
    ApptStatus? status,
    String? staffId,
  }) => Appointment(
    id: a.id,
    petId: a.petId,
    serviceId: a.serviceId,
    staffId: staffId ?? a.staffId,
    start: start ?? a.start,
    durationMinutes: durationMinutes ?? a.durationMinutes,
    status: status ?? a.status,
    price: a.price,
    sickPet: a.sickPet,
    grooming: a.grooming,
    triageSummary: a.triageSummary,
  );

  /// Auto-assign staff by service line (no vet-selection step).
  String autoAssignStaff(String serviceId) =>
      Seed.service(serviceId).role == StaffRole.groomer
      ? Seed.groomer.id
      : serviceOf(serviceId).role == StaffRole.vet
      ? Seed.vet.id
      : Seed.assistant.id;

  // ---------------------------------------------- vet medical writes
  //
  // The audit trail is enforced HERE, not in the UI: every write stamps
  // staff_id (the signed-in vet's account email — the only stable staff
  // identity before the backend) and a timestamp, so no caller can produce
  // an unaudited record. The UI never touches these fields.

  /// The staff id written into every medical record's audit trail. The
  /// signed-in account's email is the only stable staff identity in the
  /// local prototype; a signed-out dev session still stamps a fallback, so
  /// an unaudited write is impossible by construction.
  String get auditStaffId => accountEmail ?? 'clinic-staff';

  /// Display name for the audit trail: the account's registered name, falling
  /// back to the email when there is none.
  String get auditStaffName => accountName ?? accountEmail ?? 'Clinic staff';

  /// Appends a medical timeline entry to the pet's history. The audit fields
  /// (staffId + recordedAt) are stamped here — callers only supply the
  /// clinical content. Newest first, like the rest of the timeline. Returns
  /// false for an unknown petId and changes nothing.
  bool addTimelineEntry({
    required String petId,
    required String title,
    required String detail,
    StaffRole role = StaffRole.vet,
    DateTime? date,
  }) {
    final p = pet(petId);
    if (p == null) return false;
    final entry = TimelineEntry(
      id: 'te${now.microsecondsSinceEpoch}',
      petId: petId,
      date: date ?? now,
      title: title,
      detail: detail,
      role: role,
      staffName: auditStaffName,
      staffId: auditStaffId,
      recordedAt: now,
    );
    pets = pets
        .map(
          (x) => x.id == petId
              ? _withRecords(x, timeline: [entry, ...x.timeline])
              : x,
        )
        .toList();
    _savePets();
    notifyListeners();
    return true;
  }

  /// Records one or more vital readings for a pet. A reading whose label
  /// matches an existing one replaces it (a re-weigh updates the weight
  /// tile); new labels are appended. Every written reading carries the audit
  /// trail. Returns false for an unknown petId and changes nothing.
  bool recordVitals({required String petId, required List<Vital> vitals}) {
    final p = pet(petId);
    if (p == null) return false;
    final stamped = [
      for (final v in vitals)
        Vital(
          label: v.label,
          value: v.value,
          unit: v.unit,
          icon: v.icon,
          note: v.note,
          staffId: auditStaffId,
          recordedAt: now,
        ),
    ];
    final labels = {for (final v in stamped) v.label};
    final merged = [
      ...stamped,
      for (final v in p.vitals)
        if (!labels.contains(v.label)) v,
    ];
    pets = pets
        .map((x) => x.id == petId ? _withRecords(x, vitals: merged) : x)
        .toList();
    _savePets();
    notifyListeners();
    return true;
  }

  /// Issues a prescription. It lands in [prescriptions] — the same list the
  /// customer reads at Profile → Prescriptions and the shop's Rx validation
  /// checks — so the new script flows straight into the customer's record.
  /// The vet's staff_id is stamped; [issued] is the audit timestamp.
  /// [vetName] defaults to the signed-in vet's name. Returns false for an
  /// unknown product.
  bool issuePrescription({
    required String productId,
    required int refills,
    required Duration validFor,
    String? vetName,
  }) {
    if (!Seed.products.any((pr) => pr.id == productId)) return false;
    final rx = Prescription(
      id: 'rx${now.microsecondsSinceEpoch}',
      productId: productId,
      vetName: vetName ?? auditStaffName,
      issued: now,
      expires: now.add(validFor),
      refills: refills,
      staffId: auditStaffId,
    );
    prescriptions = [...prescriptions, rx];
    _savePrescriptions();
    notifyListeners();
    return true;
  }

  /// Attaches a document reference to a pet's record. On-device file picking
  /// is out of scope for this prototype, so the write records the document
  /// reference (name, kind, size) with the audit trail. Returns false for an
  /// unknown petId and changes nothing.
  bool addDocument({
    required String petId,
    required String name,
    required String kind,
    int size = 0,
  }) {
    final p = pet(petId);
    if (p == null) return false;
    final doc = PetDoc(
      name: name,
      kind: kind,
      date: now,
      size: size,
      staffId: auditStaffId,
      recordedAt: now,
    );
    pets = pets
        .map((x) => x.id == petId ? _withRecords(x, docs: [doc, ...x.docs]) : x)
        .toList();
    _savePets();
    notifyListeners();
    return true;
  }

  void _savePrescriptions() {
    final acct = _dataAccount;
    if (acct == null) return;
    final snapshot = prescriptions;
    _queueWrite(DatasetStore.writePrescriptions(acct, snapshot));
  }

  static Pet _withRecords(
    Pet p, {
    List<TimelineEntry>? timeline,
    List<Vital>? vitals,
    List<PetDoc>? docs,
  }) => Pet(
    id: p.id,
    name: p.name,
    species: p.species,
    breed: p.breed,
    sex: p.sex,
    birthDate: p.birthDate,
    weightKg: p.weightKg,
    heightCm: p.heightCm,
    lengthCm: p.lengthCm,
    color: p.color,
    microchip: p.microchip,
    allergies: p.allergies,
    vitals: vitals ?? p.vitals,
    timeline: timeline ?? p.timeline,
    docs: docs ?? p.docs,
    photo: p.photo,
  );

  // ------------------------------------------------------------------ cart
  int qtyOf(String productId) =>
      cart.where((c) => c.productId == productId).fold(0, (a, b) => a + b.qty);

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      removeFromCart(productId);
      return;
    }
    final clamped = math.min(qty, 20);
    final exists = cart.any((c) => c.productId == productId);
    cart = [
      for (final c in cart)
        if (c.productId == productId) c.copyWith(qty: clamped) else c,
      if (!exists) CartLine(productId, clamped),
    ];
    _saveCart();
    notifyListeners();
  }

  void addToCart(String productId, [int qty = 1]) =>
      setQty(productId, qtyOf(productId) + qty);

  void removeFromCart(String productId) {
    cart = cart.where((c) => c.productId != productId).toList();
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    cart = const [];
    _saveCart();
    notifyListeners();
  }

  int get cartCount => cart.fold(0, (a, b) => a + b.qty);

  double get cartTotal =>
      cart.fold(0.0, (a, c) => a + productOf(c.productId).price * c.qty);

  double get cartWeight =>
      cart.fold(0.0, (a, c) => a + productOf(c.productId).price * c.qty);

  /// Restricted items need an active prescription signed by the veterinarian.
  List<String> get blockedRestricted => [
    for (final c in cart)
      if (productOf(c.productId).restricted && !hasPrescription(c.productId))
        c.productId,
  ];

  bool hasPrescription(String productId) =>
      prescriptions.any((p) => p.productId == productId && p.activeAt(now));

  // ---------------------------------------------------------------- orders
  void addOrder(Order o) {
    orders = [o, ...orders];
    _saveOrders();
    // A paid order waits on prep — staff push alert, same rules as above.
    if (o.status == OrderStatus.paid) {
      vetPush.raise(
        VetAlert.orderPlaced(
          orderId: o.id,
          pickupCode: o.pickupCode,
          itemCount: o.lines.fold(0, (n, l) => n + l.qty),
          customerName: ownerFirstName,
          at: o.placedAt,
        ),
      );
    }
    notifyListeners();
  }

  void updateOrder(String id, Order Function(Order) f) {
    orders = orders.map((o) => o.id == id ? f(o) : o).toList();
    _saveOrders();
    notifyListeners();
  }

  // ------------------------------------------------------------------ chat
  void pushMessage(ChatMessage m) {
    messages = [...messages, m];
    _saveMessages();
    _raiseVetAlertFor(m);
    notifyListeners();
  }

  /// Vet push trigger (Task 8): alerts fire where queue items are created,
  /// never by polling the queue.
  ///
  /// - A customer-shared triage handoff → one urgent alert. The message IS
  ///   the sharing record (see the queue contract), and [handOffToClinic] is
  ///   its only creator — an unshared triage result can never alert.
  /// - A customer reply in a non-AI thread → one normal alert (a chat waiting
  ///   on staff). AI-thread traffic, staff/AI replies and system messages
  ///   never alert — they are not new demand for the vet queue.
  /// - Messages pushed from the vet's own sending session never alert: the
  ///   real vet-send path (ChatThreadScreen._sendText/_sendImage) posts with
  ///   sentByMe: true, which the "customer reply" branch would otherwise
  ///   read as new demand and turn into a self-alert.
  void _raiseVetAlertFor(ChatMessage m) {
    if (m.kind == ChatKind.triageHandoff) {
      vetPush.raise(
        VetAlert.triageHandoff(
          messageId: m.id,
          petName: m.petId == null ? 'A pet' : (pet(m.petId!)?.name ?? 'A pet'),
          summary: m.triageSummary ?? m.text,
          at: m.at,
        ),
      );
      return;
    }
    // The vet answering is not new demand for the vet queue.
    if (shell == AppShell.vet) return;
    if (!m.sentByMe || m.kind == ChatKind.system) return;
    final isAi = Seed.threads.any((t) => t.id == m.threadId && t.isAi);
    if (isAi) return;
    vetPush.raise(
      VetAlert.chatReply(
        messageId: m.id,
        threadId: m.threadId,
        customerName: ownerFirstName,
        snippet: m.text.isEmpty ? 'Photo' : m.text,
        at: m.at,
      ),
    );
  }

  List<ChatMessage> thread(String id) =>
      messages.where((m) => m.threadId == id).toList();

  /// Per-thread read marker for the vet inbox: the [now] of the newest
  /// message the vet has seen in each thread. Unset means never opened — every
  /// incoming message counts as unread. Kept in memory (like the vet shell
  /// itself): it tracks a viewing session, not account data.
  final Map<String, DateTime> _vetReadAt = {};

  /// Unread count for the vet inbox in [threadId]: customer-side messages —
  /// customer-sent, or the customer-shared triage handoff (the sharing record
  /// itself, per the queue's contract) — newer than the vet's last read
  /// marker. System messages and staff replies never count.
  int vetUnread(String threadId) {
    final readAt = _vetReadAt[threadId];
    return thread(threadId).where((m) {
      if (m.kind == ChatKind.system) return false;
      if (!m.sentByMe && m.kind != ChatKind.triageHandoff) return false;
      return readAt == null || m.at.isAfter(readAt);
    }).length;
  }

  /// Marks [threadId] as read by the vet up to [now]. Called when the vet
  /// opens a thread, and when the vet sends in one (the vet has obviously
  /// seen their own reply, so it must not inflate the badge).
  void markVetThreadRead(String threadId) {
    _vetReadAt[threadId] = now;
    notifyListeners();
  }

  // ------------------------------------------------------------- settings
  void setLanguage(String l) {
    language = l;
    notifyListeners();
    unawaited(SettingsStore.writeLanguage(l));
  }

  void setThemeMode(ThemeMode mode) {
    if (themeMode == mode) return;
    themeMode = mode;
    notifyListeners();
    unawaited(SettingsStore.writeThemeMode(mode));
  }

  /// Kept for the Appearance rows and existing tests: a boolean choice always
  /// means an explicit override, never "follow the system".
  void setDarkMode(bool v) =>
      setThemeMode(v ? ThemeMode.dark : ThemeMode.light);

  void setReduceMotion(bool v) {
    reduceMotionOverride = v;
    notifyListeners();
    unawaited(SettingsStore.writeReduceMotion(v));
  }

  /// Test seam: `test/screens_test.dart` drives the dark golden with
  /// `s.darkMode = true`. Kept as a real setter so it behaves like the
  /// Appearance toggle (explicit override + persist + notify).
  set darkMode(bool v) => setDarkMode(v);

  /// Marks the first-launch flow done. Called once the user reaches Home
  /// through splash → onboarding → register, so every later launch goes
  /// straight from the splash into the app and the flow never repeats.
  void completeFirstLaunch() {
    if (onboardingCompleted) return;
    onboardingCompleted = true;
    notifyListeners();
    unawaited(SettingsStore.writeOnboardingCompleted(true));
  }

  /// Restores the persisted preferences. Safe to call in tests and on desktop:
  /// [SettingsStore] swallows plugin failures and the defaults stand.
  ///
  /// Also restores the auth session: a saved session email means the user was
  /// signed in when the process died, so the app comes back signed in instead
  /// of dropping to login. The session's persisted datasets (pets,
  /// appointments, cart, …) are rehydrated; only on a first launch with no
  /// stored data does the demo account fall back to its seed dataset and a
  /// registered account to an empty one (B15).
  Future<void> loadSettings() async {
    final mode = await SettingsStore.readThemeMode();
    final reduce = await SettingsStore.readReduceMotion();
    final lang = await SettingsStore.readLanguage();
    final completed = await SettingsStore.readOnboardingCompleted();

    themeMode = ThemeMode.fromName(mode);
    reduceMotionOverride = reduce ?? false;
    language = lang ?? language;
    if (completed != null) {
      onboardingCompleted = completed;
    } else {
      // One-time migration: anyone who already used the app (legacy flag)
      // counts as having completed the first-launch flow.
      onboardingCompleted = await SettingsStore.readOnboarded();
      await SettingsStore.writeOnboardingCompleted(onboardingCompleted);
    }

    final sessionEmail = await SettingsStore.readSessionEmail();
    if (sessionEmail != null && sessionEmail.isNotEmpty) {
      signedIn = true;
      accountEmail = sessionEmail;
      accountName = await AuthStore.displayName(sessionEmail);
      _shell = _shellForRole(await AuthStore.roleFor(sessionEmail));
      // A restored session rehydrates its own persisted datasets — the seeds
      // are only the first-launch fallback, never an overwrite.
      await _rehydrate(accountEmail!, registered: accountName != null);
      await _loadOwnerProfile();
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------- auth

  /// Demo credentials. Real ones would live behind a server; for this
  /// prototype they are checked in the client, which is why the flow is a
  /// design demonstration rather than actual security.
  static const demoEmail = 'carepaws@test.com';
  static const demoPassword = 'carepawscustomer1';

  bool signedIn = false;

  /// The post-auth shell for the signed-in account. `customer` until a vet
  /// signs in; reset to `customer` on sign-out. The root router reads this to
  /// pick the shell, and the vet route guard reads it to deny cross-role
  /// navigation.
  AppShell get shell => _shell;
  AppShell _shell = AppShell.customer;

  /// Maps a stored role string onto a shell. Only 'vet' is privileged —
  /// anything else (null, unknown, demo) is customer-side.
  static AppShell _shellForRole(String? role) =>
      role == 'vet' ? AppShell.vet : AppShell.customer;

  /// Set while a sign-in attempt is in flight, so the button can show a spinner.
  bool signingIn = false;

  /// User-facing reason the last attempt failed. Null when there was no error.
  String? signInError;

  /// Display name of the signed-in user. Null for the demo account (which
  /// uses the seeded owner name) and when signed out.
  String? accountName;

  /// Email of the signed-in account, normalized to lowercase.
  String? accountEmail;

  /// Registers a new local account and returns true on success; on failure
  /// [signInError] names the problem.
  ///
  /// Registration never signs in: the login screen takes the user back to
  /// sign-in so they enter the credentials they just created.
  Future<bool> register(
    String name,
    String email,
    String password, {
    DateTime? agreedToTermsAt,
  }) async {
    signingIn = true;
    signInError = null;
    notifyListeners();

    // A short pause so the button state is visible — the check itself is local.
    await Future<void>.delayed(const Duration(milliseconds: 420));

    final err = await AuthStore.register(
      name: name,
      email: email,
      password: password,
      agreedToTermsAt: agreedToTermsAt,
    );

    signingIn = false;
    if (err != null) {
      signInError = err;
      notifyListeners();
      return false;
    }
    signInError = null;
    notifyListeners();
    return true;
  }

  /// Validates against registered local accounts first, then the demo
  /// credentials. The email is compared without case or surrounding space.
  /// Returns true only on success, leaving [signedIn] false on any mismatch.
  Future<bool> signIn(String email, String password) async {
    signingIn = true;
    signInError = null;
    notifyListeners();

    // A short pause so the button state is visible — the check itself is local.
    await Future<void>.delayed(const Duration(milliseconds: 420));

    // Registered accounts take precedence over the demo login.
    final registeredName = await AuthStore.authenticate(email, password);
    final okEmail = email.trim().toLowerCase() == demoEmail;
    final okPass = password == demoPassword;

    signingIn = false;
    signedIn = registeredName != null || (okEmail && okPass);
    if (signedIn) {
      accountName = registeredName; // null for the demo account
      accountEmail = email.trim().toLowerCase();
      signInError = null;
      // The demo account is never stored in AuthStore, so roleFor falls back
      // to 'customer' for it — the demo stays customer-side by construction.
      _shell = _shellForRole(await AuthStore.roleFor(accountEmail!));
      // Rehydrate this account's persisted datasets. The fallback keeps the
      // old semantics: a registered account starts with a clean slate (B15),
      // the demo account with its seed dataset.
      await _rehydrate(accountEmail!, registered: registeredName != null);
      await SettingsStore.writeSessionEmail(accountEmail!);
      await _loadOwnerProfile();
      // A vet signing in after open picks up anything batched overnight.
      vetPush.checkDigestDue();
    } else {
      accountName = null;
      accountEmail = null;
      _profileName = null;
      _profilePhone = '';
      // One neutral message either way: naming which half was wrong would
      // confirm that the email exists on this device.
      signInError = "Email and password don't match. Try again.";
    }
    notifyListeners();
    return signedIn;
  }

  /// Clears the session and any error, so the splash → login flow can be shown
  /// again from Settings. Also clears the persisted session email so a
  /// relaunch after sign-out boots to login, not back into the account.
  void signOut() {
    signedIn = false;
    signInError = null;
    signingIn = false;
    accountName = null;
    accountEmail = null;
    _profileName = null;
    _profilePhone = '';
    _shell = AppShell.customer;
    unawaited(SettingsStore.clearSessionEmail());
    notifyListeners();
  }

  /// Stores a key entered in Settings for one AI provider and re-probes, so
  /// the live status updates without a restart. Returns whether that
  /// provider is actually answering now.
  Future<bool> setAiKeyFor(AiProvider provider, String key) async {
    final ok = await ai.useKeyFor(provider, key);
    notifyListeners();
    return ok;
  }

  /// Appends a key to one provider's failover pool and re-probes. Returns
  /// whether the provider is actually answering now.
  Future<bool> addAiKeyFor(AiProvider provider, String key) async {
    final ok = await ai.addKeyFor(provider, key);
    notifyListeners();
    return ok;
  }

  /// Removes one key from a provider's failover pool and re-probes.
  Future<void> removeAiKeyFor(AiProvider provider, String key) async {
    await ai.removeKeyFor(provider, key);
    notifyListeners();
  }

  /// The provider's on-device keys, masked for display, best-first.
  List<String> aiKeyPoolFor(AiProvider provider) =>
      ai.statusFor(provider).keyPool;

  /// Forgets one provider's on-device key; the app falls back to a
  /// build-time key or to the next ready provider, whichever is in play.
  Future<void> clearAiKeyFor(AiProvider provider) => setAiKeyFor(provider, '');

  /// Switches one AI provider on or off and re-probes.
  Future<void> setAiProviderEnabled(AiProvider provider, bool enabled) async {
    await ai.setProviderEnabled(provider, enabled);
    notifyListeners();
  }

  /// Re-probes every configured AI provider. Settings calls this for
  /// "Test connection".
  Future<void> recheckAi() async {
    await ai.recheck();
    notifyListeners();
  }

  /// AI → clinic handoff carries the pet and the triage result, so the user
  /// never retypes anything.
  void handOffToClinic({required Pet pet, required TriageResult result}) {
    pushMessage(
      ChatMessage(
        id: 'h${now.microsecondsSinceEpoch}',
        threadId: 'th_clinic',
        author: ChatAuthor.ai,
        text:
            'Health check for ${pet.name} (${pet.breed}): ${result.title}. ${result.summary}',
        at: now,
        kind: ChatKind.triageHandoff,
        petId: pet.id,
        triageSummary: result.summary,
      ),
    );
    final first = ownerFirstName;
    final thanks = first.isEmpty ? 'Thanks' : 'Thanks, $first';
    // Dynamic, role-matched reply via the shared composer (B5) — the old
    // inline hardcoded strings are gone.
    final reply = ChatMessage(
      id: 'r${now.microsecondsSinceEpoch}',
      threadId: 'th_clinic',
      author: ChatAuthor.vetAssistant,
      text:
          '$thanks! ${composeStaffReply(role: StaffRole.vetAssistant, userText: 'health check handoff: ${result.title}', petName: pet.name, clinicOpen: staffOnline())}',
      at: now.add(const Duration(minutes: 1)),
      petId: pet.id,
    );
    messages = [...messages, reply];
    _saveMessages();
    notifyListeners();
  }

  // ------------------------------------------------------------ lifecycle
  /// Datasets are keyed per account, so two accounts on one device never
  /// share pets, carts or chats. Null while signed out — nothing is saved.
  String? get _dataAccount => accountEmail;

  /// In-flight dataset writes. Production saves are fire-and-forget (the
  /// documents are small and written at commit points, never per keystroke);
  /// tests flush them with [flushPersistence].
  final List<Future<void>> _pendingWrites = [];

  void _queueWrite(Future<void> f) => _pendingWrites.add(f);

  /// Test seam: awaits every fire-and-forget dataset write issued so far, so
  /// tests can assert on-device state deterministically.
  Future<void> flushPersistence() async {
    final pending = List.of(_pendingWrites);
    _pendingWrites.clear();
    await Future.wait(pending);
  }

  /// Each save serializes the list as it stands at the call site — the async
  /// write may run after a later mutation, so handing the live field to the
  /// writer would let rapid successive edits race.
  void _savePets() {
    final acct = _dataAccount;
    if (acct == null) return;
    final snapshot = pets;
    _queueWrite(DatasetStore.writePets(acct, snapshot));
  }

  void _saveAppointments() {
    final acct = _dataAccount;
    if (acct == null) return;
    final snapshot = appointments;
    _queueWrite(DatasetStore.writeAppointments(acct, snapshot));
  }

  void _saveReminders() {
    final acct = _dataAccount;
    if (acct == null) return;
    final snapshot = reminders;
    _queueWrite(DatasetStore.writeReminders(acct, snapshot));
  }

  void _saveOrders() {
    final acct = _dataAccount;
    if (acct == null) return;
    final snapshot = orders;
    _queueWrite(DatasetStore.writeOrders(acct, snapshot));
  }

  void _saveMessages() {
    final acct = _dataAccount;
    if (acct == null) return;
    final snapshot = messages;
    _queueWrite(DatasetStore.writeMessages(acct, snapshot));
  }

  void _saveHealthChecks() {
    final acct = _dataAccount;
    if (acct == null) return;
    final snapshot = healthResults;
    _queueWrite(DatasetStore.writeHealthChecks(acct, snapshot));
  }

  /// Records a completed health check (newest last) and persists it.
  void recordHealthResult(HealthCheckResult result) {
    healthResults = [...healthResults, result];
    _saveHealthChecks();
    notifyListeners();
  }

  /// The most recent health-check result for [petId], or null when the pet
  /// has never been checked. Stream B's chat button consumes this.
  HealthCheckResult? latestHealthResult(String petId) {
    HealthCheckResult? latest;
    for (final r in healthResults) {
      if (r.petId != petId) continue;
      if (latest == null || r.createdAt.isAfter(latest.createdAt)) {
        latest = r;
      }
    }
    return latest;
  }

  void _saveNotifications() {
    final acct = _dataAccount;
    if (acct == null) return;
    final snapshot = notifications;
    _queueWrite(DatasetStore.writeNotifications(acct, snapshot));
  }

  void _saveCart() {
    final acct = _dataAccount;
    if (acct == null) return;
    final snapshot = cart;
    _queueWrite(DatasetStore.writeCart(acct, snapshot));
  }

  /// Rehydrates every persisted dataset for [account]. Stored data always
  /// wins; the fallback preserves the old boot semantics — the demo account
  /// starts from its seed dataset, a registered account from an empty one
  /// (B15) — so first launches are unchanged.
  Future<void> _rehydrate(String account, {required bool registered}) async {
    pets =
        await DatasetStore.readPets(account) ??
        (registered ? const <Pet>[] : Seed.pets);
    appointments =
        await DatasetStore.readAppointments(account) ??
        (registered ? const <Appointment>[] : Seed.appointments);
    orders =
        await DatasetStore.readOrders(account) ??
        (registered ? const <Order>[] : Seed.orders);
    messages =
        await DatasetStore.readMessages(account) ??
        (registered ? const <ChatMessage>[] : Seed.messages);
    reminders =
        await DatasetStore.readReminders(account) ??
        (registered ? const <Reminder>[] : Seed.reminders);
    notifications =
        await DatasetStore.readNotifications(account) ??
        (registered ? const <AppNotification>[] : Seed.notifications);
    prescriptions =
        await DatasetStore.readPrescriptions(account) ??
        (registered ? const <Prescription>[] : Seed.prescriptions);
    cart = await DatasetStore.readCart(account) ?? const <CartLine>[];
    healthResults =
        await DatasetStore.readHealthChecks(account) ??
        const <HealthCheckResult>[];
  }
}

/// Scopes [AppStore] to the widget tree.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing — safe inside callbacks.
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing, and null when there is no store above — used by
  /// `design/` helpers that must also work in isolated widget tests.
  static AppStore? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()?.notifier;
}
