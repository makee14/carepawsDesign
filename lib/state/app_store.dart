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
import 'profile_store.dart';

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
    return 'The clinic team is offline until 9:00 AM $when.';
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

  /// Used by the zero-pet empty state / demo reset.
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
    notifyListeners();
  }

  void updateAppointment(String id, Appointment Function(Appointment) f) {
    appointments = appointments.map((a) => a.id == id ? f(a) : a).toList();
    _saveAppointments();
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
  String autoAssignStaff(String serviceId) =>
      Seed.service(serviceId).role == StaffRole.groomer
      ? Seed.groomer.id
      : serviceOf(serviceId).role == StaffRole.vet
      ? Seed.vet.id
      : Seed.assistant.id;

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
    notifyListeners();
  }

  List<ChatMessage> thread(String id) =>
      messages.where((m) => m.threadId == id).toList();

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
      // Rehydrate this account's persisted datasets. The fallback keeps the
      // old semantics: a registered account starts with a clean slate (B15),
      // the demo account with its seed dataset.
      await _rehydrate(accountEmail!, registered: registeredName != null);
      await SettingsStore.writeSessionEmail(accountEmail!);
      await _loadOwnerProfile();
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

  /// Demo reset path: restores the seed dataset, but ONLY for the demo
  /// account. A registered account keeps its own data — the seeds are
  /// demo-only and must never resurrect under a real account.
  void reset() {
    cart = const [];
    if (signedIn && accountName == null) {
      pets = Seed.pets;
      appointments = Seed.appointments;
      orders = Seed.orders;
      messages = Seed.messages;
      reminders = Seed.reminders;
      // Persist the reset state too: without this a cold start after a demo
      // reset would resurrect the pre-reset data from disk.
      _savePets();
      _saveAppointments();
      _saveOrders();
      _saveMessages();
      _saveReminders();
    }
    _saveCart();
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
