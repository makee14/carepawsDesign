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

/// Six-step booking flow:
/// 1 Pet → 2 AI Triage → 3 Service → 4 Date & time → 5 Review → 6 Confirm.
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
  String? _serviceId;
  DateTime? _date;
  TimeOfDay? _time;
  TriageResult? _triage;
  bool _skipTriage = false;
  String _intakeSize = 'Medium';
  String _intakeCoat = 'Short, dense, healthy';
  final _notes = TextEditingController();
  bool _confirming = false;

  bool get _skipTriageStep => widget.rebookFrom != null;

  @override
  void initState() {
    super.initState();
    _triage = widget.triage;
    _skipTriage = _triage == null;
    final r = widget.rebookFrom;
    if (r != null) {
      _petId = r.petId;
      _serviceId = r.serviceId;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _petId ??= widget.initialPetId ?? AppScope.of(context).pets.firstOrNull?.id;
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

  DateTime? get _slot {
    if (_date == null || _time == null) return null;
    return DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
  }

  bool _canContinue() => switch (_step) {
    0 => _petId != null,
    1 => true, // triage is optional — result or explicit skip
    2 => _serviceId != null,
    3 => _slot != null,
    4 => _slot != null && _serviceId != null,
    _ => false,
  };

  Future<void> _next() async {
    HapticFeedback.selectionClick();
    if (_step < 4) {
      setState(() => _step++);
      return;
    }
    await _confirm();
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
    // Step 6: confirmation, then the success sheet.
    setState(() => _step = 5);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final steps = _skipTriageStep ? 5 : 6;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: _step >= 5 ? 'Confirmed' : 'Book · Step ${_step + 1} of $steps',
        showBack: _step < 5,
        actions: [
          if (_step < 5)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  _stepName(_step, _skipTriageStep),
                  style: Type.caption(p),
                ),
              ),
            ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (_step < 5) _ProgressBar(step: _step, total: steps),
            // Keyed per step: otherwise the step ListViews share one
            // ScrollableState and a new step would open scrolled down.
            Expanded(
              child: KeyedSubtree(key: ValueKey(_step), child: _body(store)),
            ),
            StickyCta(
              extra: (_step > 0 && _step < 5)
                  ? SecondaryButton(
                      label: 'Back',
                      icon: Ic.chevronLeft,
                      onPressed: () => setState(() => _step--),
                    )
                  : null,
              child: PrimaryButton(
                label: switch (_step) {
                  5 => 'Done',
                  4 => 'Confirm booking',
                  _ => 'Continue',
                },
                icon: switch (_step) {
                  5 => Ic.check,
                  4 => Ic.check,
                  _ => Ic.arrowRight,
                },
                busy: _confirming,
                // Step 6 (index 5) is the confirmation: Done lands on the
                // Appointments tab, the section the booking belongs to —
                // not wherever the flow was opened from.
                onPressed: _step == 5
                    ? () => doneToTab(context, 2)
                    : (_canContinue() ? _next : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stepName(int step, bool skip) {
    final names = skip
        ? ['Pet', 'Service', 'Date & time', 'Review', 'Confirm']
        : ['Pet', 'Triage', 'Service', 'Date & time', 'Review', 'Confirm'];
    return names[step];
  }

  Widget _body(AppStore store) {
    return switch (_step) {
      0 => _petStep(store),
      1 => _triageStep(store),
      2 => _serviceStep(store),
      3 => _dateStep(store),
      4 => _reviewStep(store),
      _ => _doneStep(store),
    };
  }

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
  Widget _triageStep(AppStore store) {
    final p = context.p;
    final pet = store.pet(_petId ?? '');
    if (_skipTriage) {
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
                      child: Text(
                        'Run a health check',
                        style: Type.headline(p),
                      ),
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
                    final result = await Navigator.of(context)
                        .push<TriageResult>(
                          CupertinoPageRoute<TriageResult>(
                            builder: (_) => TriageScreen(
                              entry: TriageEntry.booking,
                              preselectedPetId: _petId,
                              showSkip: true,
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
          const SizedBox(height: T.s12),
          SecondaryButton(
            label: 'Skip triage',
            onPressed: () => setState(() => _skipTriage = true),
          ),
          if (_triage != null) ...[
            const SizedBox(height: T.s20),
            _TriageSummaryCard(result: _triage!),
          ],
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('AI health check complete', style: Type.title1(p)),
        const SizedBox(height: 16),
        _TriageSummaryCard(result: _triage!),
        const SizedBox(height: T.s20),
        SecondaryButton(
          label: 'Run it again',
          icon: Ic.refresh,
          onPressed: () => setState(() => _triage = null),
        ),
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

  // ------------------------------------------------------ step 4: date & time
  Widget _dateStep(AppStore store) {
    final p = context.p;
    final s = _service;
    if (s == null) return const SizedBox.shrink();
    final days = _next14Days(store.now);
    final slots = _slotsFor(store.now, s);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Pick a date & time', style: Type.title1(p)),
        const SizedBox(height: 6),
        Text(
          '${s.name} takes ${s.durationLabel}, so slots are spaced accordingly.',
          style: Type.footnote(p),
        ),
        const SizedBox(height: T.s20),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final d = days[i];
              final selected = _date?.day == d.day && _date?.month == d.month;
              return Semantics(
                button: true,
                selected: selected,
                label:
                    '${shortDate(d)}${isToday(d, store.now) ? ', today' : ''}',
                child: ExcludeSemantics(
                  child: PressScale(
                    onTap: () => setState(() {
                      _date = d;
                      _time = null;
                    }),
                    child: Container(
                      width: 68,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? p.primaryFill : p.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? p.primaryFill : p.divider,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayNames[d.weekday - 1],
                            style: Type.caption(p).copyWith(
                              color: selected
                                  ? p.onPrimaryFill
                                  : p.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${d.day}',
                            style: Type.title2(p).copyWith(
                              color: selected ? p.onPrimaryFill : p.text,
                            ),
                          ),
                          Text(
                            monthNames[d.month - 1],
                            style: Type.caption(p).copyWith(
                              color: selected
                                  ? p.onPrimaryFill.withValues(alpha: 0.9)
                                  : p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: T.s20),
        if (_date == null)
          Text('Choose a date to see available times.', style: Type.footnote(p))
        else if (slots.isEmpty)
          Text(
            'No slots left on this day — try the next one.',
            style: Type.footnote(p),
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
                  slot: slot,
                  selected:
                      _time?.hour == slot.hour && _time?.minute == slot.minute,
                  onTap: () => setState(
                    () =>
                        _time = TimeOfDay(hour: slot.hour, minute: slot.minute),
                  ),
                ),
            ],
          ),
        ],
        if (s.grooming && _serviceId != null) ...[
          const SizedBox(height: T.s24),
          _GroomingIntake(
            size: _intakeSize,
            coat: _intakeCoat,
            notes: _notes,
            onSize: (v) => setState(() => _intakeSize = v),
            onCoat: (v) => setState(() => _intakeCoat = v),
            onNotesChanged: () => setState(() {}),
          ),
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

  // ------------------------------------------------------------------ slots
  List<DateTime> _next14Days(DateTime from) => [
    for (var i = 0; i < 14; i++) DateTime(from.year, from.month, from.day + i),
  ];

  /// Slot spacing follows the service duration: grooming 1–2h, assistant
  /// 15–20m, vet consults 30m.
  List<DateTime> _slotsFor(DateTime from, Service s) {
    if (_date == null) return const [];
    final day = _date!;
    final floor = switch (s.role) {
      StaffRole.groomer => const Duration(minutes: 60),
      StaffRole.vet => const Duration(minutes: 30),
      StaffRole.vetAssistant => const Duration(minutes: 15),
    };
    final len = Duration(minutes: s.durationMinutes);
    final step = len > floor ? len : floor;
    final open = day.weekday == DateTime.sunday ? 9 : 8;
    final close = day.weekday == DateTime.sunday ? 16 : 19;
    final out = <DateTime>[];
    var t = DateTime(day.year, day.month, day.day, open);
    while (t.hour < close) {
      if (t.isAfter(from.add(const Duration(minutes: 30)))) out.add(t);
      t = t.add(step);
    }
    return out;
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
  });
  final DateTime slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      selected: selected,
      label: clockLabel(slot),
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
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
