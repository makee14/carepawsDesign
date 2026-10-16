import 'package:flutter/cupertino.dart';

import '../../../app.dart'
    show
        appRoute,
        clockLabel,
        confirmDestructive,
        dayNames,
        dismissSheet,
        mediumDate,
        shortDate;
import '../../../data/clinic.dart';
import '../../../data/models.dart';
import '../../../data/scheduling.dart';
import '../../../data/seed.dart';
import '../../../design/icons.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../state/app_store.dart';
import '../../../widgets/common.dart';
import '../../appointments/appointment_detail_screen.dart';
import '../../appointments_screen.dart' show statusBg, statusFg, statusIcon;

/// The vet's appointment card for the Schedule day view: time, pet, service,
/// assignee, and status chip up top; the status-appropriate actions below.
///
/// Tapping the card opens the shared [AppointmentDetailScreen] (the same one
/// the queue uses) — no dead ends, no vet-only duplicate detail screen.
class VetScheduleCard extends StatelessWidget {
  const VetScheduleCard({
    super.key,
    required this.appointment,
    required this.store,
  });

  final Appointment appointment;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final a = appointment;
    final pet = store.pet(a.petId);
    final service = store.serviceOf(a.serviceId);
    final staff = store.staffOf(a.staffId);
    final actions = _actions(context);
    // AX5: side-by-side rows (time + status chip, staff + assign) would
    // overflow — stack them instead. Scale-gated so the 1x path is
    // pixel-identical.
    final big = MediaQuery.textScalerOf(context).scale(1) > 1.0;

    final timeBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${clockLabel(a.start)} – ${clockLabel(a.end)}',
          style: Type.headline(p),
        ),
        const SizedBox(height: 2),
        Text(
          '${pet?.name ?? 'Pet'} · ${service.name}',
          style: Type.subheadline(p).copyWith(color: p.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final statusChip = StatusChip(
      label: a.status.short,
      icon: statusIcon(a.status),
      compact: true,
      fg: statusFg(a.status, p.isDark),
      bg: statusBg(a.status, p.isDark),
    );
    final staffText = Text(
      'With ${staff.name} · ${staff.role.short}',
      style: Type.footnote(p).copyWith(color: p.textSecondary),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final assignButton = _VetAction(
      label: 'Assign',
      icon: Ic.person,
      onTap: () => _openStaffPicker(context),
    );

    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          Navigator.of(context)
              .push(appRoute(AppointmentDetailScreen(appointmentId: a.id))),
      semanticLabel:
          '${pet?.name}, ${service.name}, ${clockLabel(a.start)}, status ${a.status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(T.s16, T.s12, T.s16, 0),
            child: big
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      timeBlock,
                      const SizedBox(height: T.s8),
                      statusChip,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: timeBlock),
                      const SizedBox(width: T.s8),
                      statusChip,
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(T.s16, T.s8, T.s16, 0),
            child: big
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      staffText,
                      const SizedBox(height: T.s8),
                      assignButton,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: staffText),
                      assignButton,
                    ],
                  ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: T.s12),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(T.s12),
              // Wrap, not Row: at AX5 the actions reflow to two lines
              // instead of pushing past the screen edge. Every action is a
              // full-width ≥46pt button — one deliberate stacked column,
              // easy to hit with a thumb.
              child: Wrap(spacing: T.s8, runSpacing: T.s8, children: actions),
            ),
          ] else
            const SizedBox(height: T.s12),
        ],
      ),
    );
  }

  /// The actions the vet can take from this card, driven by the appointment's
  /// status — the store enforces the same chain, so the UI can never offer an
  /// illegal transition.
  List<Widget> _actions(BuildContext context) {
    final a = appointment;
    final service = store.serviceOf(a.serviceId);
    switch (a.status) {
      case ApptStatus.requestPending:
        return [
          PrimaryButton(
            label: 'Confirm',
            icon: Ic.check,
            compact: true,
            expand: true,
            onPressed: () => store.confirmAppointment(a.id),
          ),
          _VetAction(
            label: 'Reschedule',
            icon: Ic.calendar,
            onTap: () => _openReschedule(context),
          ),
          _VetAction(
            label: 'Cancel',
            icon: Ic.close,
            destructive: true,
            onTap: () => _cancel(context),
          ),
        ];
      case ApptStatus.confirmed:
      case ApptStatus.booked:
        return [
          PrimaryButton(
            label: service.grooming ? 'Start grooming' : 'Mark complete',
            icon: service.grooming ? Ic.scissors : Ic.check,
            compact: true,
            expand: true,
            onPressed: () => store.advanceAppointment(a.id),
          ),
          _VetAction(
            label: 'Reschedule',
            icon: Ic.calendar,
            onTap: () => _openReschedule(context),
          ),
          _VetAction(
            label: 'Cancel',
            icon: Ic.close,
            destructive: true,
            onTap: () => _cancel(context),
          ),
        ];
      case ApptStatus.beingGroomed:
        return [
          PrimaryButton(
            label: 'Ready for pickup',
            icon: Ic.gift,
            compact: true,
            expand: true,
            onPressed: () => store.advanceAppointment(a.id),
          ),
        ];
      case ApptStatus.readyForPickup:
        return [
          PrimaryButton(
            label: 'Mark complete',
            icon: Ic.check,
            compact: true,
            expand: true,
            onPressed: () => store.advanceAppointment(a.id),
          ),
        ];
      case ApptStatus.completed:
      case ApptStatus.cancelled:
        return const [];
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final a = appointment;
    final ok = await confirmDestructive(
      context,
      title: 'Cancel this appointment?',
      message:
          'The ${store.serviceOf(a.serviceId).name.toLowerCase()} for '
          '${store.pet(a.petId)?.name ?? 'this pet'} on ${mediumDate(a.start)} '
          'will be released.',
      confirmLabel: 'Cancel appointment',
    );
    if (!ok || !context.mounted) return;
    AppScope.read(context).cancelAppointment(a.id);
  }

  void _openReschedule(BuildContext context) {
    showPopup(
      context,
      builder: (ctx) => _RescheduleSheet(appointment: appointment),
    );
  }

  void _openStaffPicker(BuildContext context) {
    showPopup(context, builder: (ctx) => _StaffSheet(appointment: appointment));
  }
}

/// Secondary pill action: 46pt minimum height, tinted fill, wraps its label
/// at large text scales.
class _VetAction extends StatelessWidget {
  const _VetAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final fg = destructive ? p.destructive : p.accentText;
    final bg = destructive
        ? p.destructive.withValues(alpha: 0.12)
        : p.accent.withValues(alpha: 0.12);
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          scale: 0.96,
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(
              horizontal: T.s16,
              vertical: T.s8,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(T.rControl + 2),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ic.svg(icon, color: fg, size: 16, stroke: 2.1),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: Type.footnoteEmph(p).copyWith(color: fg),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reschedule sheet: a day picker (Sundays disabled — the clinic is closed)
/// plus the real slot grid for the chosen day, built on the shared [daySlots]
/// so the vet sees exactly the availability the booking flow enforces. The
/// store re-validates on save; the sheet can only offer legal slots.
class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({required this.appointment});

  final Appointment appointment;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late DateTime _day;
  DateTime? _slot;

  AppStore get _store => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    // getInheritedWidgetOfExactType does not subscribe, so reading the store
    // here is safe.
    final now = AppScope.read(context).now;
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(
      widget.appointment.start.year,
      widget.appointment.start.month,
      widget.appointment.start.day,
    );
    // Default to the appointment's own day when it is a bookable day.
    _day = !current.isBefore(today) && current.weekday != DateTime.sunday
        ? current
        : today;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final a = widget.appointment;
    final service = _store.serviceOf(a.serviceId);
    final staff = _store.staffOf(a.staffId);
    // The appointment being moved must not block its own target slot.
    final others = _store.appointments.where((x) => x.id != a.id).toList();
    final slots = daySlots(_day, service, staff, others, _store.now);
    final storeToday = _store.now;
    final today = DateTime(storeToday.year, storeToday.month, storeToday.day);
    final days = List.generate(21, (i) => today.add(Duration(days: i)));
    void save() {
      final target = _slot;
      if (target == null) return;
      if (_store.rescheduleAppointment(a.id, target) && context.mounted) {
        dismissSheet(context);
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (sheetCtx, scrollController) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            T.s20,
            T.s12,
            T.s20,
            T.s20 + MediaQuery.paddingOf(sheetCtx).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.taupe.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: T.s16),
              Text('Reschedule', style: Type.title2(p)),
              const SizedBox(height: 4),
              Text(
                '${service.name} · ${staff.name}',
                style: Type.footnote(p).copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: T.s16),
              SizedBox(
                height: Layout.scale(context, 76),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: T.s8),
                  itemBuilder: (ctx, i) => _sheetDayCell(ctx, days[i], p),
                ),
              ),
              const SizedBox(height: T.s16),
              Text('Available times', style: Type.headline(p)),
              const SizedBox(height: 4),
              Text(
                Clinic.hoursRangeLabel,
                style: Type.footnote(p).copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: T.s8),
              if (slots.isEmpty)
                Text(
                  _day.weekday == DateTime.sunday
                      ? 'Closed on Sundays — pick another day.'
                      : 'No open slots this day — pick another day.',
                  style: Type.subheadline(p).copyWith(color: p.textSecondary),
                )
              else
                Wrap(
                  spacing: T.s8,
                  runSpacing: T.s8,
                  children: [
                    for (final slot in slots)
                      _SlotChip(
                        slot: slot,
                        selected: _slot == slot.start,
                        onTap: slot.available
                            ? () => setState(() => _slot = slot.start)
                            : null,
                      ),
                  ],
                ),
              const SizedBox(height: T.s20),
              PrimaryButton(
                label: _slot == null
                    ? 'Pick a time'
                    : 'Move to ${shortDate(_slot!)} · ${clockLabel(_slot!)}',
                onPressed: _slot == null ? null : save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetDayCell(BuildContext context, DateTime day, AppPalette p) {
    final selected =
        day.year == _day.year && day.month == _day.month && day.day == _day.day;
    final sunday = day.weekday == DateTime.sunday;
    final fg = selected
        ? (p.isDark ? T.espresso : T.card)
        : sunday
        ? p.textSecondary
        : p.text;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: shortDate(day),
      child: ExcludeSemantics(
        child: PressScale(
          onTap: sunday
              ? null
              : () => setState(() {
                  _day = day;
                  _slot = null;
                }),
          child: Opacity(
            opacity: sunday ? 0.55 : 1,
            child: Container(
              // AX5: widen with Dynamic Type instead of clipping the
              // weekday/number — pixel-identical at 1x.
              width: Layout.scale(context, 56),
              padding: EdgeInsets.symmetric(vertical: Layout.scale(context, 8)),
              decoration: BoxDecoration(
                color: selected ? p.accent : p.surface,
                borderRadius: BorderRadius.circular(T.s16),
                border: selected ? null : Border.all(color: p.divider),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayNames[day.weekday - 1],
                    style: Type.caption(p).copyWith(color: fg),
                  ),
                  Text(
                    '${day.day}',
                    style: Type.headline(p).copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One slot chip: 44pt minimum, filled when selected, ghosted when taken.
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final DaySlot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final fg = selected
        ? (p.isDark ? T.espresso : T.card)
        : slot.available
        ? p.accentText
        : p.textSecondary;
    final bg = selected
        ? p.accent
        : slot.available
        ? p.accent.withValues(alpha: 0.12)
        : p.surface;
    return Opacity(
      opacity: slot.available ? 1 : 0.6,
      child: PressScale(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 76),
          padding: const EdgeInsets.symmetric(
            horizontal: T.s12,
            vertical: T.s8,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(T.rControl),
            border: slot.available && !selected
                ? Border.all(color: p.divider)
                : null,
          ),
          child: Text(
            clockLabel(slot.start),
            style: Type.footnoteEmph(p).copyWith(color: fg),
          ),
        ),
      ),
    );
  }
}

/// Staff picker sheet: every staffer in [Seed.staff], the current assignee
/// checked. The appointment model carries the assignment as [staffId], so no
/// schema change was needed.
class _StaffSheet extends StatelessWidget {
  const _StaffSheet({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.read(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (sheetCtx, scrollController) => Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            T.s20,
            T.s12,
            T.s20,
            T.s20 + MediaQuery.paddingOf(sheetCtx).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.taupe.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: T.s16),
              Text('Assign staff', style: Type.title2(p)),
              const SizedBox(height: T.s12),
              for (final member in Seed.staff)
                _staffRow(context, store, member, p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _staffRow(
    BuildContext context,
    AppStore store,
    Staff member,
    AppPalette p,
  ) {
    final current = member.id == appointment.staffId;
    return PressScale(
      onTap: () {
        store.assignStaff(appointment.id, member.id);
        dismissSheet(context);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(vertical: T.s8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                member.initials,
                style: Type.footnoteEmph(p).copyWith(color: p.accentText),
              ),
            ),
            const SizedBox(width: T.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(member.name, style: Type.headline(p)),
                  Text(
                    '${member.role.label} · ${member.focus}',
                    style: Type.footnote(p).copyWith(color: p.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (current) Ic.svg(Ic.check, color: p.accentText, size: 20),
          ],
        ),
      ),
    );
  }
}
