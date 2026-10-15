import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/clinic.dart';
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../services/ai_service.dart';
import '../../state/app_store.dart';
import '../../widgets/ai_unavailable.dart';
import '../../widgets/common.dart';
import '../../widgets/time_of_day.dart';
import '../triage_screen.dart';
import '../profile/settings_screens.dart';

/// Booking flow — each step does exactly one job:
/// Pet → AI Triage → Service → Service details (grooming only) →
/// Date & time → Review → Confirm.
///
/// The triage step is optional (Continue works without it); there is no skip
/// button. The details step only exists for services with per-service
/// questions (currently grooming: size, coat, notes), so step indices shift
/// with the selected service — [_flow] is the single source of truth.
enum _Step { pet, triage, service, questions, dateTime, review, confirm }

/// One theoretical slot on a day, with its real availability.
class _DaySlot {
  const _DaySlot({required this.start, required this.available});
  final DateTime start;
  final bool available;
}

class BookFlow extends StatefulWidget {
  const BookFlow({
    super.key,
    this.initialPetId,
    this.triage,
    this.rebookFrom,
    this.onBooked,
  });

  final String? initialPetId;

  /// Pre-filled triage result (from the triage engine or a previous outcome).
  final TriageResult? triage;

  /// Rebooking skips triage entirely.
  final Appointment? rebookFrom;
  final void Function(Appointment a)? onBooked;

  @override
  State<BookFlow> createState() => _BookFlowState();
}

class _BookFlowState extends State<BookFlow> {
  int _step = 0;
  String? _petId;
  String? _initialPetId;
  String? _serviceId;
  DateTime? _date;
  TimeOfDay? _time;
  DateTime? _calMonth;
  TriageResult? _triage;
  String _intakeSize = 'Medium';
  String _intakeCoat = 'Short, dense, healthy';
  final _notes = TextEditingController();
  bool _confirming = false;

  bool get _skipTriageStep => widget.rebookFrom != null;

  /// The live step order. The questions step only exists for services with
  /// per-service questions (grooming), so every index below must go through
  /// this list — never a hardcoded step number.
  List<_Step> get _flow => [
    _Step.pet,
    if (!_skipTriageStep) _Step.triage,
    _Step.service,
    if (_service?.grooming ?? false) _Step.questions,
    _Step.dateTime,
    _Step.review,
    _Step.confirm,
  ];

  /// Confirm is always last; review always second-to-last.
  int get _confirmIndex => _flow.length - 1;

  /// Anything the user did beyond the pre-selected pet: leaving the flow at
  /// step 0 with progress asks "Leave booking?" instead of popping silently.
  bool get _hasProgress =>
      _petId != _initialPetId ||
      _serviceId != null ||
      _date != null ||
      _time != null ||
      _triage != null ||
      _notes.text.trim().isNotEmpty ||
      _intakeSize != 'Medium' ||
      _intakeCoat != 'Short, dense, healthy';

  /// Nav-bar back / system back at step 0: leave only when clean or the user
  /// confirms. Confirming lands back wherever the flow was opened from — the
  /// booking itself is abandoned, not completed.
  Future<void> _exitBooking() async {
    if (await confirmDiscardIfDirty(
      context,
      isDirty: _hasProgress,
      title: 'Leave booking?',
      message: 'Your booking progress will be lost.',
    )) {
      if (mounted) dismissSheet(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _triage = widget.triage;
    final r = widget.rebookFrom;
    if (r != null) {
      _petId = r.petId;
      _serviceId = r.serviceId;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context);
    _petId ??= widget.initialPetId ?? store.pets.firstOrNull?.id;
    _initialPetId ??= _petId;
    final now = store.now;
    _calMonth ??= DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  AppStore get _store => AppScope.read(context);

  Service? get _service =>
      _serviceId == null ? null : _store.serviceOf(_serviceId!);

  Staff get _staff => _store.staffOf(_store.autoAssignStaff(_serviceId ?? ''));

  double get _total {
    final s = _service;
    if (s == null) return 0;
    final r = widget.rebookFrom;
    if (r != null && r.serviceId == s.id && r.start == _date) return r.price;
    return s.price;
  }

  /// The chosen slot, or null when the chosen day/time is no longer actually
  /// available (e.g. it was just booked). Availability is re-checked on
  /// every build so a stale pick can never slip through to review.
  DateTime? get _slot {
    if (_date == null || _time == null) return null;
    final s = _service;
    if (s == null) return null;
    final start = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    final ok = _daySlots(
      _date!,
      s,
      _staff,
      _store.now,
    ).any((sl) => sl.start == start && sl.available);
    return ok ? start : null;
  }

  bool _canContinue() => switch (_flow[_step]) {
    _Step.pet => _petId != null,
    _Step.triage => true, // triage is optional — Continue works without it
    _Step.service => _serviceId != null,
    _Step.questions => true, // every intake field is optional
    _Step.dateTime => _slot != null,
    _Step.review => _slot != null && _serviceId != null,
    _Step.confirm => false,
  };

  Future<void> _next() async {
    HapticFeedback.selectionClick();
    if (_flow[_step] != _Step.review) {
      setState(() => _step++);
      return;
    }
    await _confirm();
  }

  /// Every theoretical slot on [day] for [service] with [staff], flagged by
  /// real availability. Clinic hours come from [Clinic] (Mon–Sat 9–18,
  /// closed Sundays); a slot is unavailable when it overlaps one of the
  /// staff member's active appointments that day. Past days and Sundays
  /// return no slots at all.
  List<_DaySlot> _daySlots(
    DateTime day,
    Service service,
    Staff staff,
    DateTime now,
  ) {
    final d = DateTime(day.year, day.month, day.day);
    final today = DateTime(now.year, now.month, now.day);
    if (d.weekday == DateTime.sunday || d.isBefore(today)) return const [];
    // Slot spacing follows the service duration: grooming 1–2h, assistant
    // 15–20m, vet consults 30m.
    final floor = switch (service.role) {
      StaffRole.groomer => const Duration(minutes: 60),
      StaffRole.vet => const Duration(minutes: 30),
      StaffRole.vetAssistant => const Duration(minutes: 15),
    };
    final len = Duration(minutes: service.durationMinutes);
    final step = len > floor ? len : floor;
    final open = DateTime(d.year, d.month, d.day, Clinic.openHour);
    final close = DateTime(d.year, d.month, d.day, Clinic.closeHour);
    final booked = _store.appointments
        .where(
          (a) =>
              a.staffId == staff.id &&
              a.status.isActive &&
              a.start.year == d.year &&
              a.start.month == d.month &&
              a.start.day == d.day,
        )
        .toList();
    final lead = now.add(const Duration(minutes: 30));
    final out = <_DaySlot>[];
    // A slot must END by closing time, and start at least 30 minutes out.
    for (var t = open; !t.add(len).isAfter(close); t = t.add(step)) {
      if (t.isBefore(lead)) continue;
      final end = t.add(len);
      final clash = booked.any(
        (a) => t.isBefore(a.end) && a.start.isBefore(end),
      );
      out.add(_DaySlot(start: t, available: !clash));
    }
    return out;
  }

  /// The first day from [from] (inclusive) with at least one available slot,
  /// or null when the whole booking window is full.
  DateTime? _nextAvailableDay(
    DateTime from,
    Service service,
    Staff staff,
    DateTime now,
    DateTime maxDay,
  ) {
    var d = DateTime(from.year, from.month, from.day);
    final last = DateTime(maxDay.year, maxDay.month, maxDay.day);
    while (!d.isAfter(last)) {
      if (_daySlots(d, service, staff, now).any((s) => s.available)) return d;
      d = d.add(const Duration(days: 1));
    }
    return null;
  }

  Future<void> _confirm() async {
    final store = _store;
    final service = _service!;
    final slot = _slot!;
    final sick = _triage?.urgency == 2 || (_triage?.urgency ?? 0) >= 1;
    setState(() => _confirming = true);

    // Routine bookings confirm instantly; sick-pet visits are a request the
    // vet assistant confirms.
    final status = sick && service.role == StaffRole.vet
        ? ApptStatus.requestPending
        : service.grooming
        ? ApptStatus.booked
        : ApptStatus.confirmed;

    final a = Appointment(
      id: 'n${store.now.microsecondsSinceEpoch}',
      petId: _petId!,
      serviceId: service.id,
      staffId: _staff.id,
      start: slot,
      durationMinutes: service.durationMinutes,
      status: status,
      price: _total,
      sickPet: sick,
      grooming: service.grooming
          ? GroomingIntake(
              size: '$_intakeSize (${store.pet(_petId!)?.weightKg} kg)',
              coat: _intakeCoat,
              notes: _notes.text.trim(),
            )
          : null,
      triageSummary: _triage?.summary,
    );
    store.addAppointment(a);
    if (!mounted) return;
    successHaptic();

    if (widget.onBooked != null) {
      widget.onBooked!(a);
      dismissSheet(context);
      return;
    }

    setState(() => _confirming = false);
    if (!mounted) return;
    // Last step: the confirmation.
    setState(() => _step = _confirmIndex);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final steps = _flow.length;
    final atConfirm = _step >= _confirmIndex;

    // Android system back mirrors the nav-bar back exactly: step > 0 steps
    // back inside the flow, step 0 asks "Leave booking?" when there is
    // progress, and the confirmed screen blocks it entirely (Done lands on
    // the Appointments tab instead). A direct dismissSheet pop bypasses
    // PopScope, so the confirmed exit needs no flag dance.
    return PopScope(
      canPop: _step == 0 && !_hasProgress,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_step >= _confirmIndex) return; // confirmed: swallow system back
        if (_step > 0) {
          setState(() => _step--);
          return;
        }
        await _exitBooking();
      },
      child: CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: DetailNavBar(
          title: atConfirm ? 'Confirmed' : 'Book · Step ${_step + 1} of $steps',
          showBack: !atConfirm,
          // Step > 0: nav-bar back steps back inside the flow (previously it
          // maybePop'd and silently abandoned the booking). Step 0: the leave
          // confirm when there is progress.
          onBack: _step == 0
              ? () => _exitBooking()
              : !atConfirm
              ? () => setState(() => _step--)
              : null,
          actions: [
            if (!atConfirm)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(_stepName(_flow[_step]), style: Type.caption(p)),
                ),
              ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (!atConfirm) _ProgressBar(step: _step, total: steps),
              // Keyed per step identity: otherwise the step ListViews share
              // one ScrollableState and a new step would open scrolled down.
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey(_flow[_step]),
                  child: _body(store),
                ),
              ),
              StickyCta(
                extra: (_step > 0 && !atConfirm)
                    ? SecondaryButton(
                        label: 'Back',
                        icon: Ic.chevronLeft,
                        onPressed: () => setState(() => _step--),
                      )
                    : null,
                child: PrimaryButton(
                  label: switch (_flow[_step]) {
                    _Step.confirm => 'Done',
                    _Step.review => 'Confirm booking',
                    _ => 'Continue',
                  },
                  icon: switch (_flow[_step]) {
                    _Step.confirm => Ic.check,
                    _Step.review => Ic.check,
                    _ => Ic.arrowRight,
                  },
                  busy: _confirming,
                  // The confirmation's Done lands on the Appointments tab,
                  // the section the booking belongs to — not wherever the
                  // flow was opened from.
                  onPressed: _flow[_step] == _Step.confirm
                      ? () => doneToTab(context, 2)
                      : (_canContinue() ? _next : null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _stepName(_Step step) => switch (step) {
    _Step.pet => 'Pet',
    _Step.triage => 'Triage',
    _Step.service => 'Service',
    _Step.questions => 'Details',
    _Step.dateTime => 'Date & time',
    _Step.review => 'Review',
    _Step.confirm => 'Confirm',
  };

  Widget _body(AppStore store) => switch (_flow[_step]) {
    _Step.pet => _petStep(store),
    _Step.triage => _triageStep(store),
    _Step.service => _serviceStep(store),
    _Step.questions => _questionsStep(store),
    _Step.dateTime => _dateTimeStep(store),
    _Step.review => _reviewStep(store),
    _Step.confirm => _doneStep(store),
  };

  // ------------------------------------------------------------ step 1: pet
  Widget _petStep(AppStore store) {
    final p = context.p;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Who is this visit for?', style: Type.title1(p)),
        const SizedBox(height: 6),
        Text(
          'Pre-selected from your last booking — change it if you like.',
          style: Type.footnote(p),
        ),
        const SizedBox(height: T.s20),
        if (store.pets.isEmpty)
          EmptyState(
            icon: Ic.paw,
            title: 'No pets yet',
            body: 'Add a pet before booking so we can attach the visit to their record.',
            actionLabel: 'Add pet',
            onAction: () =>
                Navigator.of(context).push(appRoute(const _NoPetYet())),
          )
        else
          for (final pet in store.pets)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                button: true,
                selected: _petId == pet.id,
                label: '${pet.name}, ${pet.breed}',
                child: ExcludeSemantics(
                  child: PressScale(
                    onTap: () => setState(() => _petId = pet.id),
                    child: SoftCard(
                      padding: const EdgeInsets.all(12),
                      borderColor: _petId == pet.id ? p.accent : null,
                      color: _petId == pet.id
                          ? T.amber.withValues(alpha: 0.12)
                          : null,
                      child: Row(
                        children: [
                          PetArt(
                            seed: pet.id.hashCode.abs() % 4,
                            species: pet.species,
                            radius: 14,
                            iconSize: 40,
                            label: '${pet.name} portrait',
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(pet.name, style: Type.headline(p)),
                                const SizedBox(height: 2),
                                Text(
                                  '${pet.breed} · ${pet.ageLabel} · ${pet.weightKg} kg',
                                  style: Type.footnote(p),
                                ),
                              ],
                            ),
                          ),
                          SelectDot(selected: _petId == pet.id),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  // --------------------------------------------------------- step 2: triage
  // --------------------------------------------------------- triage step
  // The check is optional — Continue moves on without it, so there is no
  // skip button. A completed check shows its summary inline.
  Widget _triageStep(AppStore store) {
    final p = context.p;
    final pet = store.pet(_petId ?? '');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('AI health check', style: Type.title1(p)),
        const SizedBox(height: 6),
        Text(
          'Optional, and it changes nothing about your booking.',
          style: Type.footnote(p),
        ),
        const SizedBox(height: T.s24),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Ic.svg(Ic.sparkle, color: p.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Run a health check', style: Type.headline(p)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Describe the symptoms or attach a photo. CarePaws AI sorts ${pet?.name ?? 'your pet'} '
                'into booking, chat or home care — and flags anything urgent.',
                style: Type.body(p).copyWith(color: p.textSecondary),
              ),
              if (store.ai.status == AiStatus.unavailable) ...[
                const SizedBox(height: T.s16),
                AiUnavailableCard(
                  failure: store.ai.failure ?? AiFailure.noKey,
                  onOpenSettings: () =>
                      Navigator.of(context)
                          .push(appRoute(const AiSettingsScreen())),
                  onCall: () => callPhoneNumber(
                    context,
                    number: Clinic.phone,
                    name: Clinic.name,
                  ),
                ),
              ],
              const SizedBox(height: T.s16),
              PrimaryButton(
                label: 'Start health check',
                icon: Ic.sparkle,
                onPressed: () async {
                  final result = await Navigator.of(context).push<TriageResult>(
                    appRouteT<TriageResult>(
                      TriageScreen(
                        entry: TriageEntry.booking,
                        preselectedPetId: _petId,
                        onComplete: (r) => Navigator.of(context).pop(r),
                      ),
                    ),
                  );
                  if (result != null) setState(() => _triage = result);
                },
              ),
            ],
          ),
        ),
        if (_triage != null) ...[
          const SizedBox(height: T.s20),
          _TriageSummaryCard(result: _triage!),
          const SizedBox(height: T.s12),
          SecondaryButton(
            label: 'Run it again',
            icon: Ic.refresh,
            onPressed: () => setState(() => _triage = null),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------- step 3: service
  Widget _serviceStep(AppStore store) {
    final p = context.p;
    final pet = store.pet(_petId ?? '');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'What does ${pet?.name ?? 'your pet'} need?',
          style: Type.title1(p),
        ),
        const SizedBox(height: 6),
        Text(
          'Staff are assigned automatically by service line.',
          style: Type.footnote(p),
        ),
        const SizedBox(height: T.s20),
        for (final s in Seed.services)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              button: true,
              selected: _serviceId == s.id,
              label:
                  '${s.name}. ${s.blurb}. ${s.durationLabel}. ${s.priceNote == null ? peso(s.price) : '${s.priceNote} ${peso(s.price)}'}',
              child: ExcludeSemantics(
                child: PressScale(
                  onTap: () => setState(() {
                    _serviceId = s.id;
                    _date = null;
                    _time = null;
                  }),
                  child: SoftCard(
                    padding: const EdgeInsets.all(14),
                    borderColor: _serviceId == s.id ? p.accent : null,
                    color: _serviceId == s.id
                        ? T.amber.withValues(alpha: 0.12)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: p.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Center(
                                child: Ic.svg(
                                  s.icon,
                                  color: p.primaryFill,
                                  size: 21,
                                  stroke: 1.9,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(s.name, style: Type.headline(p)),
                                  const SizedBox(height: 2),
                                  Text(s.blurb, style: Type.footnote(p)),
                                ],
                              ),
                            ),
                            SelectDot(selected: _serviceId == s.id),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusChip(
                              label: s.durationLabel,
                              icon: Ic.clock,
                              compact: true,
                            ),
                            StatusChip(
                              label: s.priceNote == null
                                  ? peso(s.price)
                                  : '${s.priceNote} ${peso(s.price)}',
                              icon: Ic.wallet,
                              compact: true,
                              fg: p.accentText,
                              bg: p.accent.withValues(alpha: 0.12),
                            ),
                            StatusChip(
                              label: s.role.short,
                              icon: s.role == StaffRole.groomer
                                  ? Ic.scissors
                                  : Ic.heartPulse,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --------------------------------------------- service questions step
  // One job: the per-service questions (the grooming intake today). This
  // step only exists in the flow for services that have questions.
  Widget _questionsStep(AppStore store) {
    final p = context.p;
    final s = _service;
    if (s == null) return const SizedBox.shrink();
    final staff = _staff;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Service details', style: Type.title1(p)),
        const SizedBox(height: 6),
        Text(
          'So ${staff.firstName} can prepare — everything here is optional.',
          style: Type.footnote(p),
        ),
        const SizedBox(height: T.s20),
        if (s.grooming)
          _GroomingIntake(
            size: _intakeSize,
            coat: _intakeCoat,
            notes: _notes,
            onSize: (v) => setState(() => _intakeSize = v),
            onCoat: (v) => setState(() => _intakeCoat = v),
            onNotesChanged: () => setState(() {}),
          ),
      ],
    );
  }

  // ------------------------------------------------- date & time step
  // One job: the calendar plus the assigned staff member's real
  // availability. Nothing else lives here — the service questions moved to
  // their own step.
  Widget _dateTimeStep(AppStore store) {
    final p = context.p;
    final s = _service;
    if (s == null) return const SizedBox.shrink();
    final staff = _staff;
    final now = store.now;
    final today = DateTime(now.year, now.month, now.day);
    // Booking opens two weeks out.
    final maxDay = today.add(const Duration(days: 13));

    // No availability anywhere in the window: the call card is the only
    // action — never a dead end.
    final firstAvailable = _nextAvailableDay(today, s, staff, now, maxDay);
    if (firstAvailable == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Pick a date & time', style: Type.title1(p)),
          const SizedBox(height: T.s20),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Ic.svg(Ic.calendar, color: p.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No availability right now',
                        style: Type.headline(p),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'We couldn\'t find an open time for ${s.name.toLowerCase()} in the next two weeks.',
                  style: Type.body(p).copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: T.s16),
                PrimaryButton(
                  label: 'Call the clinic',
                  icon: Ic.phone,
                  onPressed: () => callPhoneNumber(
                    context,
                    number: Clinic.phone,
                    name: Clinic.name,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final day = _date;
    final slots = day == null
        ? const <_DaySlot>[]
        : _daySlots(day, s, staff, now);
    final anyAvailable = slots.any((sl) => sl.available);
    // The suggestion after a full day: the next open day past the selection,
    // falling back to the earliest open day in the window.
    final nextPast = day == null
        ? null
        : _nextAvailableDay(
            day.add(const Duration(days: 1)),
            s,
            staff,
            now,
            maxDay,
          );
    final suggestion = nextPast ?? firstAvailable;

    final thisMonth = DateTime(now.year, now.month);
    final maxMonth = DateTime(maxDay.year, maxDay.month);
    final calMonth = _calMonth ?? thisMonth;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Pick a date & time', style: Type.title1(p)),
        const SizedBox(height: 6),
        Text(
          '${s.name} takes ${s.durationLabel}. Times shown are ${staff.name}\'s real availability.',
          style: Type.footnote(p),
        ),
        const SizedBox(height: T.s20),
        _MonthCalendar(
          month: calMonth,
          selected: day,
          now: now,
          maxDay: maxDay,
          onSelectDay: (d) => setState(() {
            _date = d;
            _time = null;
          }),
          onPrevMonth: calMonth.isAfter(thisMonth)
              ? () => setState(
                  () => _calMonth = DateTime(calMonth.year, calMonth.month - 1),
                )
              : null,
          onNextMonth: calMonth.isBefore(maxMonth)
              ? () => setState(
                  () => _calMonth = DateTime(calMonth.year, calMonth.month + 1),
                )
              : null,
        ),
        const SizedBox(height: T.s20),
        if (day == null)
          Text(
            'Choose a day to see ${staff.name}\'s available times.',
            style: Type.footnote(p),
          )
        else if (!anyAvailable)
          _EmptyDayCard(
            day: day,
            staffName: staff.name,
            suggestion: suggestion,
            suggestionLabel: nextPast != null
                ? 'Next available'
                : 'Earliest available',
            onJump: (d) => setState(() {
              _calMonth = DateTime(d.year, d.month);
              _date = d;
              _time = null;
            }),
          )
        else ...[
          Text('Available times', style: Type.headline(p)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final slot in slots)
                _TimePill(
                  slot: slot.start,
                  selected:
                      _time?.hour == slot.start.hour &&
                      _time?.minute == slot.start.minute,
                  enabled: slot.available,
                  onTap: () => setState(
                    () => _time = TimeOfDay(
                      hour: slot.start.hour,
                      minute: slot.start.minute,
                    ),
                  ),
                ),
            ],
          ),
          if (slots.any((sl) => !sl.available)) ...[
            const SizedBox(height: 8),
            Text(
              'Greyed-out times are already booked.',
              style: Type.caption(p).copyWith(color: p.textSecondary),
            ),
          ],
        ],
      ],
    );
  }

  // --------------------------------------------------------- step 5: review
  Widget _reviewStep(AppStore store) {
    final p = context.p;
    final s = _service;
    final pet = store.pet(_petId ?? '');
    final slot = _slot;
    final staff = _staff;
    if (s == null || slot == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Review', style: Type.title1(p)),
        const SizedBox(height: 6),
        Text('Check the details, then confirm.', style: Type.footnote(p)),
        const SizedBox(height: T.s20),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PetArt(
                    seed: (pet?.id.hashCode.abs() ?? 0) % 4,
                    species: pet?.species,
                    radius: 14,
                    iconSize: 40,
                    label: '${pet?.name} portrait',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(pet?.name ?? 'Pet', style: Type.headline(p)),
                        Text(pet?.breed ?? '', style: Type.footnote(p)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: p.divider),
              AmountRow(label: 'Service', value: s.name),
              AmountRow(label: 'Date & time', value: mediumDate(slot)),
              AmountRow(label: 'Duration', value: s.durationLabel),
              const SizedBox(height: 6),
              Divider(height: 1, color: p.divider),
              const SizedBox(height: 12),
              Text('Assigned staff', style: Type.headline(p)),
              const SizedBox(height: 10),
              Row(
                children: [
                  StaffAvatar(
                    initials: staff.initials,
                    size: 44,
                    role: staff.role,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(staff.name, style: Type.headline(p)),
                        const SizedBox(height: 2),
                        Text(
                          '${staff.role.label} · ${staff.focus}',
                          style: Type.footnote(p),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (s.grooming) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: p.divider),
                const SizedBox(height: 12),
                Text('Grooming intake', style: Type.headline(p)),
                const SizedBox(height: 8),
                AmountRow(
                  label: 'Size',
                  value: '$_intakeSize (${pet?.weightKg} kg)',
                ),
                AmountRow(label: 'Coat condition', value: _intakeCoat),
                if (_notes.text.trim().isNotEmpty)
                  AmountRow(label: 'Notes', value: _notes.text.trim()),
              ],
              if (_triage != null) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: p.divider),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Ic.svg(Ic.sparkle, color: p.accent, size: 16),
                    const SizedBox(width: 7),
                    Text('Health check', style: Type.headline(p)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_triage!.summary, style: Type.footnote(p)),
                const SizedBox(height: 8),
                StatusChip(
                  label: _triage!.urgencyLabel,
                  icon: Ic.info,
                  compact: true,
                  fg: _triage!.urgency == 2 ? p.destructive : p.warning,
                  bg: _triage!.urgency == 2
                      ? const Color(0x1FDC2626)
                      : T.amber.withValues(alpha: 0.26),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: T.s16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: Type.headline(p)),
              const SizedBox(height: 4),
              AmountRow(
                label: s.priceNote == null ? s.name : '${s.priceNote} price',
                value: peso(_total),
                bold: true,
              ),
              if (s.priceNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Final grooming price is confirmed at the counter after coat assessment.',
                    style: Type.caption(p),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Ic.svg(Ic.info, color: p.textSecondary, size: 15),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      (_triage?.urgency ?? 0) >= 1 && s.role == StaffRole.vet
                          ? 'This goes in as a request — the vet assistant confirms it, usually within clinic hours.'
                          : 'Routine bookings confirm instantly.',
                      style: Type.caption(p),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- step 6: done
  Widget _doneStep(AppStore store) {
    final p = context.p;
    final a = store.upcoming.firstWhere(
      (x) => x.id.startsWith('n'),
      orElse: () => store.upcoming.first,
    );
    final pet = store.pet(a.petId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0x1FDDF2E3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Ic.svg(
                Ic.checkCircle,
                color: p.success,
                size: 42,
                stroke: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: T.s20),
        Text(
          a.status == ApptStatus.requestPending
              ? 'Request sent'
              : 'You are booked',
          style: Type.largeTitle(p),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          a.status == ApptStatus.requestPending
              ? '${pet?.name}’s ${store.serviceOf(a.serviceId).name.toLowerCase()} request is with the vet assistant. '
                    'We will confirm by SMS once it is reviewed.'
              : '${pet?.name} is booked for ${store.serviceOf(a.serviceId).name.toLowerCase()} '
                    'with ${store.staffOf(a.staffId).name}.',
          style: Type.body(p).copyWith(color: p.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: T.s24),
        SoftCard(
          child: Column(
            children: [
              AmountRow(label: 'When', value: mediumDate(a.start), bold: true),
              AmountRow(label: 'Where', value: Seed.clinicName),
              AmountRow(label: 'Total', value: peso(a.price), bold: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      label: 'Step ${step + 1} of $total',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: T.pressMs),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= step ? p.accent : p.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.slot,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });
  final DateTime slot;
  final bool selected;
  final VoidCallback onTap;

  /// Booked slots stay visible but dimmed and untappable — the day's real
  /// availability at a glance.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: clockLabel(slot),
      child: ExcludeSemantics(
        child: PressScale(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.38,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: T.pressMs),
              constraints: const BoxConstraints(minHeight: 44, minWidth: 88),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? p.primaryFill : p.surface,
                borderRadius: BorderRadius.circular(T.rControl),
                border: Border.all(color: selected ? p.primaryFill : p.divider),
              ),
              child: Text(
                clockLabel(slot),
                style: Type.callout(p).copyWith(
                  color: selected ? p.onPrimaryFill : p.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Month-grid calendar, Cupertino-consistent: abbreviated month + year,
/// Monday-first weekday row, 44pt day targets. Past days, Sundays (clinic
/// closed) and days past the booking window are dimmed and untappable.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.now,
    required this.maxDay,
    required this.onSelectDay,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  /// Any day in the displayed month.
  final DateTime month;

  /// The selected day (date-only), or null.
  final DateTime? selected;
  final DateTime now;

  /// Last selectable day (date-only).
  final DateTime maxDay;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback? onPrevMonth;
  final VoidCallback? onNextMonth;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first: Monday leaves no blanks.
    final leadBlanks = first.weekday - 1;
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(maxDay.year, maxDay.month, maxDay.day);

    bool selectable(DateTime d) =>
        !d.isBefore(today) && !d.isAfter(last) && d.weekday != DateTime.sunday;

    return Column(
      children: [
        Row(
          children: [
            _MonthNavButton(
              icon: Ic.chevronLeft,
              label: 'Previous month',
              onTap: onPrevMonth,
            ),
            Expanded(
              child: Text(
                '${monthNames[month.month - 1]} ${month.year}',
                style: Type.title2(p),
                textAlign: TextAlign.center,
              ),
            ),
            _MonthNavButton(
              icon: Ic.chevronRight,
              label: 'Next month',
              onTap: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final w in dayNames)
              Expanded(
                child: Text(
                  w,
                  style: Type.caption(p).copyWith(color: p.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 46,
          ),
          itemCount: leadBlanks + daysInMonth,
          itemBuilder: (context, i) {
            if (i < leadBlanks) return const SizedBox.shrink();
            final d = DateTime(month.year, month.month, i - leadBlanks + 1);
            final isSel = selected != null && isToday(d, selected!);
            final isT = isToday(d, today);
            final ok = selectable(d);
            return Semantics(
              button: true,
              enabled: ok,
              selected: isSel,
              label:
                  '${isT ? 'Today, ' : ''}${shortDate(d)}${d.weekday == DateTime.sunday ? ', clinic closed' : ''}',
              child: ExcludeSemantics(
                child: PressScale(
                  onTap: ok ? () => onSelectDay(d) : null,
                  child: Center(
                    child: Opacity(
                      opacity: ok ? 1 : 0.35,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: isSel
                            ? BoxDecoration(
                                color: p.primaryFill,
                                shape: BoxShape.circle,
                              )
                            : isT
                            ? BoxDecoration(
                                border: Border.all(color: p.accent, width: 1.5),
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text(
                          '${d.day}',
                          style: Type.body(p).copyWith(
                            color: isSel
                                ? p.onPrimaryFill
                                : ok
                                ? p.text
                                : p.textSecondary,
                            fontWeight: isSel || isT
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          Clinic.hoursLabel,
          style: Type.caption(p).copyWith(color: p.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.3 : 1,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Ic.svg(icon, color: p.accentText, size: 20, stroke: 2.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A selected day with zero availability: clear messaging plus a one-tap
/// jump to the suggested open day — never a dead end.
class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard({
    required this.day,
    required this.staffName,
    required this.suggestion,
    required this.suggestionLabel,
    required this.onJump,
  });

  final DateTime day;
  final String staffName;
  final DateTime? suggestion;
  final String suggestionLabel;
  final ValueChanged<DateTime> onJump;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No times left on ${dayMonth(day)}', style: Type.headline(p)),
          const SizedBox(height: 6),
          Text(
            '$staffName is fully booked that day.',
            style: Type.body(p).copyWith(color: p.textSecondary),
          ),
          if (suggestion != null) ...[
            const SizedBox(height: T.s16),
            PrimaryButton(
              label: '$suggestionLabel: ${shortDate(suggestion!)}',
              icon: Ic.arrowRight,
              onPressed: () => onJump(suggestion!),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroomingIntake extends StatelessWidget {
  const _GroomingIntake({
    required this.size,
    required this.coat,
    required this.notes,
    required this.onSize,
    required this.onCoat,
    this.onNotesChanged,
  });

  final String size;
  final String coat;
  final TextEditingController notes;
  final ValueChanged<String> onSize;
  final ValueChanged<String> onCoat;
  final VoidCallback? onNotesChanged;

  static const sizes = ['Small', 'Medium', 'Large'];
  static const coats = [
    'Short, dense, healthy',
    'Long, needs detangling',
    'Double coat, shedding',
    'Matted in places',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Grooming intake', style: Type.headline(p)),
          const SizedBox(height: 4),
          Text(
            'Helps Ana plan the cut and quote accurately.',
            style: Type.footnote(p),
          ),
          const SizedBox(height: 14),
          Text('Breed / size', style: Type.footnoteEmph(p)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sizes)
                FilterPill(
                  label: s,
                  selected: size == s,
                  onTap: () => onSize(s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Coat condition', style: Type.footnoteEmph(p)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in coats)
                FilterPill(
                  label: c,
                  selected: coat == c,
                  onTap: () => onCoat(c),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Notes for the groomer', style: Type.footnoteEmph(p)),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: notes,
            onChanged: (_) => onNotesChanged?.call(),
            placeholder: 'Anything Ana should know',
            placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
            style: Type.body(p),
            minLines: 3,
            maxLines: 5,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.fieldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.divider),
            ),
          ),
        ],
      ),
    );
  }
}

class _TriageSummaryCard extends StatelessWidget {
  const _TriageSummaryCard({required this.result});
  final TriageResult result;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final tone = switch (result.route) {
      TriageRoute.emergency => p.destructive,
      TriageRoute.book => p.primaryFill,
      TriageRoute.homeCare => p.warning,
      TriageRoute.chat => p.primaryFill,
    };
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Ic.svg(Ic.sparkle, color: tone, size: 20),
              const SizedBox(width: 9),
              Expanded(child: Text(result.title, style: Type.headline(p))),
            ],
          ),
          const SizedBox(height: 10),
          StatusChip(
            label:
                '${result.urgencyLabel} · routes to ${_routeLabel(result.route)}',
            icon: Ic.arrowRight,
            compact: true,
            fg: tone,
            bg: tone.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 10),
          Text(result.summary, style: Type.body(p)),
          if (result.redFlags.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final f in result.redFlags.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Ic.svg(Ic.alert, color: p.destructive, size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: Type.footnote(p))),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Text('Guidance only — not a diagnosis.', style: Type.caption(p)),
        ],
      ),
    );
  }

  static String _routeLabel(TriageRoute r) => switch (r) {
    TriageRoute.book => 'book appointment',
    TriageRoute.chat => 'clinic chat',
    TriageRoute.homeCare => 'home care',
    TriageRoute.emergency => 'emergency call',
  };
}

class _NoPetYet extends StatelessWidget {
  const _NoPetYet();

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: context.p.background,
    navigationBar: const DetailNavBar(title: 'Add pet'),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(T.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic.svg(Ic.paw, color: context.p.accent, size: 44),
            const SizedBox(height: T.s16),
            Text(
              'Add a pet from the Home tab first',
              style: Type.title2(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Once a pet is on file, visits, vaccines and documents attach to their record automatically.',
              style: Type.body(context.p)
                  .copyWith(color: context.p.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
