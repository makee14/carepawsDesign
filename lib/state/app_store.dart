import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../data/models.dart';
import '../data/seed.dart';
import '../data/clinic.dart';
import '../design/theme.dart' show ThemeMode;
import '../services/ai_service.dart';
import '../services/photo_store.dart';
import '../services/settings_store.dart';

/// Single source of truth for the whole app. A lightweight ChangeNotifier is
/// enough here — the prototype has no need for a heavier state package.
class AppStore extends ChangeNotifier {
  AppStore({AiService? ai, DateTime? now})
    : ai = ai ?? AiService(),
      _now = now ?? DateTime.now();

  final AiService ai;
  DateTime _now;
  DateTime get now => _now;
  set now(DateTime v) {
    _now = v;
    notifyListeners();
  }

  /// Test/demo hook for deterministic screenshots.
  void advanceClock(Duration d) => now = _now.add(d);

  Timer? _clock;

  /// Starts the wall clock: `now` re-reads the device time every 30s so live
  /// countdowns, open/closed state and the upcoming/past partition stay
  /// current without user interaction. Called once from `main()`; tests drive
  /// time with [advanceClock] instead, so the timer never leaks into the test
  /// harness (a pending periodic timer fails `testWidgets` teardown).
  void startClock() {
    _clock ??= Timer.periodic(const Duration(seconds: 30), (_) {
      _now = DateTime.now();
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

  /// HIG ▸ Onboarding runs once. Replayable from Settings → Help.
  bool onboardingSeen = false;

  List<Pet> pets = Seed.pets;
  List<Appointment> appointments = Seed.appointments;
  List<Product> products = Seed.products;
  List<Reminder> reminders = Seed.reminders;
  List<Order> orders = Seed.orders;
  List<Prescription> prescriptions = Seed.prescriptions;
  List<AppNotification> notifications = Seed.notifications;
  List<ChatMessage> messages = Seed.messages;
  List<CartLine> cart = const [];

  /// Products the user asked to be notified about (out-of-stock flow).
  final Set<String> notifyMe = {};

  int _tab = 0;
  int get tab => _tab;
  set tab(int v) {
    if (_tab == v) return;
    _tab = v;
    notifyListeners();
  }

  // ------------------------------------------------------------- accessors
  String get ownerName => Seed.ownerName;

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

  /// Soonest first — the home carousel pages through these, and the
  /// Appointments list and reminders rely on the same ordering. Visits whose
  /// pet is no longer on the account are skipped, so removing a pet (or the
  /// whole account) can never leave a dangling reference on screen.
  List<Appointment> get upcomingAppointments => (appointments
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

  List<Appointment> get past => appointments
      .where((a) => !a.status.isActive || a.end.isBefore(now))
      .toList()
      ..sort((a, b) => b.start.compareTo(a.start));

  Pet? pet(String id) => pets.where((p) => p.id == id).firstOrNull;

  Appointment? appt(String id) => appointments.where((a) => a.id == id).firstOrNull;

  Appointment? apptForProduct(String productId) => appointments
      .where((a) => a.petId == 'p1')
      .firstOrNull;

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
    return 'The clinic team is offline until 9:00 AM $when.';
  }

  // ----------------------------------------------------------------- pets
  int get petCount => pets.length;

  void addPet(Pet p) {
    pets = [p, ...pets];
    if (p.hasPhoto) PhotoStore.save(PhotoStore.petKey(p.id), p.photo!);
    notifyListeners();
  }

  /// Replaces a pet in place, keeping its identity, timeline and documents.
  /// Used by the pet editor — only the editable fields change.
  void updatePet(Pet updated) {
    pets = pets
        .map((p) => p.id == updated.id ? updated : p)
        .toList();
    if (updated.hasPhoto) {
      PhotoStore.save(PhotoStore.petKey(updated.id), updated.photo!);
    } else {
      PhotoStore.remove(PhotoStore.petKey(updated.id));
    }
    notifyListeners();
  }

  /// Sets or clears one pet's portrait. Passing null restores the generated art.
  Future<void> setPetPhoto(String petId, Uint8List? bytes) async {
    pets = pets
        .map((p) => p.id == petId ? _withPhoto(p, bytes) : p)
        .toList();
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
    notifyListeners();
  }

  /// Used by the zero-pet empty state / demo reset.
  void clearPets() {
    pets = const [];
    notifyListeners();
  }

  // --------------------------------------------------------- notifications
  void markNotificationsRead() {
    notifications = notifications.map((n) => n.copyWith(read: true)).toList();
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
    notifyListeners();
  }

  void updateAppointment(String id, Appointment Function(Appointment) f) {
    appointments = appointments.map((a) => a.id == id ? f(a) : a).toList();
    notifyListeners();
  }

  void cancelAppointment(String id) =>
      updateAppointment(id, (a) => _copy(a, status: ApptStatus.cancelled));

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
  String autoAssignStaff(String serviceId) => Seed.service(serviceId).role == StaffRole.groomer
      ? Seed.groomer.id
      : serviceOf(serviceId).role == StaffRole.vet
      ? Seed.vet.id
      : Seed.assistant.id;

  // ------------------------------------------------------------------ cart
  int qtyOf(String productId) => cart.where((c) => c.productId == productId).fold(0, (a, b) => a + b.qty);

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
    notifyListeners();
  }

  void addToCart(String productId, [int qty = 1]) =>
      setQty(productId, qtyOf(productId) + qty);

  void removeFromCart(String productId) {
    cart = cart.where((c) => c.productId != productId).toList();
    notifyListeners();
  }

  void clearCart() {
    cart = const [];
    notifyListeners();
  }

  int get cartCount => cart.fold(0, (a, b) => a + b.qty);

  double get cartTotal => cart.fold(0.0, (a, c) => a + productOf(c.productId).price * c.qty);

  double get cartWeight => cart.fold(0.0, (a, c) => a + productOf(c.productId).price * c.qty);

  /// Restricted items need an active prescription signed by the veterinarian.
  List<String> get blockedRestricted => [
    for (final c in cart)
      if (productOf(c.productId).restricted && !hasPrescription(c.productId)) c.productId,
  ];

  bool hasPrescription(String productId) =>
      prescriptions.any((p) => p.productId == productId && p.activeAt(now));

  // ---------------------------------------------------------------- orders
  void addOrder(Order o) {
    orders = [o, ...orders];
    notifyListeners();
  }

  void updateOrder(String id, Order Function(Order) f) {
    orders = orders.map((o) => o.id == id ? f(o) : o).toList();
    notifyListeners();
  }

  // ------------------------------------------------------------------ chat
  void pushMessage(ChatMessage m) {
    messages = [...messages, m];
    notifyListeners();
  }

  List<ChatMessage> thread(String id) => messages.where((m) => m.threadId == id).toList();

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
  void setDarkMode(bool v) => setThemeMode(v ? ThemeMode.dark : ThemeMode.light);

  void setReduceMotion(bool v) {
    reduceMotionOverride = v;
    notifyListeners();
    unawaited(SettingsStore.writeReduceMotion(v));
  }

  /// Test seam: `test/screens_test.dart` drives the dark golden with
  /// `s.darkMode = true`. Kept as a real setter so it behaves like the
  /// Appearance toggle (explicit override + persist + notify).
  set darkMode(bool v) => setDarkMode(v);

  /// Marks the onboarding flow as done. Called for both finishing and skipping,
  /// so the flow is never re-presented on a later launch.
  void completeOnboarding() {
    if (onboardingSeen) return;
    onboardingSeen = true;
    notifyListeners();
    unawaited(SettingsStore.writeOnboarded(true));
  }

  /// Reopens the flow from Settings. Deliberately does not clear the stored
  /// flag — the user is simply being shown it again on purpose.
  void replayOnboarding() {
    onboardingSeen = false;
    notifyListeners();
  }

  /// Restores the persisted preferences. Safe to call in tests and on desktop:
  /// [SettingsStore] swallows plugin failures and the defaults stand.
  Future<void> loadSettings() async {
    final mode = await SettingsStore.readThemeMode();
    final reduce = await SettingsStore.readReduceMotion();
    final lang = await SettingsStore.readLanguage();
    final onboarded = await SettingsStore.readOnboarded();

    themeMode = ThemeMode.fromName(mode);
    reduceMotionOverride = reduce ?? false;
    language = lang ?? language;
    onboardingSeen = onboarded;
    notifyListeners();
  }

  // ------------------------------------------------------------------- auth

  /// Demo credentials. Real ones would live behind a server; for this
  /// prototype they are checked in the client, which is why the flow is a
  /// design demonstration rather than actual security.
  static const demoEmail = 'carepaws@test.com';
  static const demoPassword = 'carepawscustomer1';

  bool signedIn = false;

  /// Set while a sign-in attempt is in flight, so the button can show a spinner.
  bool signingIn = false;

  /// User-facing reason the last attempt failed. Null when there was no error.
  String? signInError;

  /// Validates against the demo credentials. The email is compared without
  /// case or surrounding space; the password must match exactly. Returns true
  /// only on success, leaving [signedIn] false on any mismatch.
  Future<bool> signIn(String email, String password) async {
    signingIn = true;
    signInError = null;
    notifyListeners();

    // A short pause so the button state is visible — the check itself is local.
    await Future<void>.delayed(const Duration(milliseconds: 420));

    final okEmail = email.trim().toLowerCase() == demoEmail;
    final okPass = password == demoPassword;

    signingIn = false;
    signedIn = okEmail && okPass;
    signInError = signedIn
        ? null
        : okEmail
        ? 'That password is not right. Try again.'
        : 'No account matches that email.';
    notifyListeners();
    return signedIn;
  }

  /// Clears the session and any error, so the splash → login flow can be shown
  /// again from Settings.
  void signOut() {
    signedIn = false;
    signInError = null;
    signingIn = false;
    notifyListeners();
  }

  /// Stores a Gemini key entered in Settings and re-probes the API so the
  /// live/demo status updates without a restart. Returns whether a usable key
  /// is now configured.
  Future<bool> setAiKey(String key) async {
    final ok = await ai.useKey(key);
    notifyListeners();
    return ok;
  }

  /// Forgets the on-device key; the app falls back to demo mode or to a
  /// build-time key, whichever is still in play.
  Future<void> clearAiKey() => setAiKey('');

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
    final reply = ChatMessage(
      id: 'r${now.microsecondsSinceEpoch}',
      threadId: 'th_clinic',
      author: ChatAuthor.vetAssistant,
      text: staffOnline()
          ? '$thanks — I have this. I will review ${pet.name}\'s chart and reply with a recommendation within clinic hours.'
          : '$thanks — this came through while we were closed. I will pick it up from 9:00 AM and reply with a recommendation.',
      at: now.add(const Duration(minutes: 1)),
      petId: pet.id,
    );
    messages = [...messages, reply];
    notifyListeners();
  }

  // ------------------------------------------------------------ lifecycle
  void reset() {
    pets = Seed.pets;
    appointments = Seed.appointments;
    orders = Seed.orders;
    cart = const [];
    messages = Seed.messages;
    reminders = Seed.reminders;
    notifyListeners();
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