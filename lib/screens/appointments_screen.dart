import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/models.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/nav_actions.dart';
import 'appointments/appointment_detail_screen.dart';
import 'appointments/book_flow.dart';

/// APPOINTMENTS — segmented Upcoming / Past.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Appointments'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              // Segmented control and the "book" action share one row.
              child: Row(
                children: [
                  Expanded(
                    child: _Segmented(
                      index: _seg,
                      labels: const ['Upcoming', 'Past'],
                      onChanged: (i) {
                        HapticFeedback.selectionClick();
                        setState(() => _seg = i);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  NavActions(
                    actions: [
                      IconTap(
                        path: Ic.plus,
                        label: 'Book a new appointment',
                        color: p.primaryFill,
                        onPressed: () => Navigator.of(context).push(
                          appRoute(
                            BookFlow(initialPetId: store.pets.firstOrNull?.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              40 + TabBarClearance.of(context),
            ),
            sliver: _seg == 0
                ? _UpcomingList(
                    store: store,
                    onBook: () => _book(context, store),
                  )
                : _PastList(store: store, onBook: () => _book(context, store)),
          ),
        ],
      ),
    );
  }

  void _book(BuildContext context, AppStore store) {
    Navigator.of(context)
        .push(appRoute(BookFlow(initialPetId: store.pets.firstOrNull?.id)));
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      label: 'Segmented control. ${labels[index]} selected',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: p.fieldBg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: T.pressMs),
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == index ? p.surface : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: i == index
                            ? const [
                                BoxShadow(
                                  color: Color(0x142A1A0E),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        labels[i],
                        style: Type.footnoteEmph(p).copyWith(
                          color: i == index ? p.text : p.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.store, required this.onBook});
  final AppStore store;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final list = store.upcoming;
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: EmptyState(
            icon: Ic.calendar,
            title: 'No upcoming appointments',
            body: 'Book a visit and we will handle the reminders for you.',
            actionLabel: 'Book appointment',
            onAction: onBook,
          ),
        ),
      );
    }
    return SliverList.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) =>
          UpcomingCard(appointment: list[i], store: store),
    );
  }
}

class _PastList extends StatelessWidget {
  const _PastList({required this.store, required this.onBook});
  final AppStore store;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final list = store.past;
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: EmptyState(
            icon: Ic.clock,
            title: 'No past visits yet',
            body: 'Completed and cancelled appointments will appear here with their receipts.',
            actionLabel: 'Book appointment',
            onAction: onBook,
          ),
        ),
      );
    }
    return SliverList.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) =>
          PastCard(appointment: list[i], store: store, onRebook: onBook),
    );
  }
}

/// Status chip colour always accompanies the text label.
Color statusFg(AppStatus s, bool dark) => switch (s) {
  AppStatus.confirmed || AppStatus.completed =>
    dark ? const Color(0xFF7FD3A0) : const Color(0xFF1F5C33),
  AppStatus.booked => dark ? T.amber : const Color(0xFF7A4A1B),
  AppStatus.requestPending =>
    dark ? const Color(0xFFFFC08A) : const Color(0xFF7A4A1B),
  AppStatus.beingGroomed => dark ? T.amber : const Color(0xFF7A4A1B),
  AppStatus.readyForPickup => dark ? T.amber : const Color(0xFF8A4A10),
  AppStatus.cancelled =>
    dark ? const Color(0xFFFF9A92) : const Color(0xFF9B1C1C),
};

Color statusBg(AppStatus s, bool dark) => switch (s) {
  AppStatus.confirmed || AppStatus.completed =>
    dark ? const Color(0x1F7FD3A0) : const Color(0xFFDDF2E3),
  AppStatus.booked || AppStatus.beingGroomed =>
    dark ? T.amber.withValues(alpha: 0.16) : const Color(0xFFFBEBD6),
  AppStatus.requestPending || AppStatus.readyForPickup =>
    dark ? T.orange.withValues(alpha: 0.18) : const Color(0xFFFDE3C7),
  AppStatus.cancelled =>
    dark ? const Color(0x1FFF9A92) : const Color(0xFFFDE2E2),
};

String statusIcon(AppStatus s) => switch (s) {
  AppStatus.confirmed || AppStatus.completed => Ic.checkCircle,
  AppStatus.booked => Ic.calendar,
  AppStatus.requestPending => Ic.clock,
  AppStatus.beingGroomed => Ic.scissors,
  AppStatus.readyForPickup => Ic.gift,
  AppStatus.cancelled => Ic.close,
};

/// Public alias so other screens can reuse the mapping.
typedef AppStatus = ApptStatus;

class UpcomingCard extends StatelessWidget {
  const UpcomingCard({
    super.key,
    required this.appointment,
    required this.store,
  });

  final Appointment appointment;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final pet = store.pet(appointment.petId);
    final service = store.serviceOf(appointment.serviceId);
    final staff = store.staffOf(appointment.staffId);
    final a = appointment;

    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          Navigator.of(context)
              .push(appRoute(AppointmentDetailScreen(appointmentId: a.id))),
      semanticLabel:
          '${pet?.name}, ${service.name}, ${mediumDate(a.start)}, ${staff.name}, status ${a.status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero band: open pet-art space, echoing the home hero card.
          SizedBox(
            height: 104,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: pet == null
                      ? PetArt(
                          seed: 0,
                          species: null,
                          iconSize: 72,
                          label: 'Pet portrait',
                        )
                      : PetAvatar(
                          pet: pet,
                          iconSize: 72,
                          label: '${pet.name} portrait',
                        ),
                ),
                Positioned(
                  left: 14,
                  top: 12,
                  // The chip floats over the (always light) PetArt hero band,
                  // so it always uses the light pair — the dark pair is
                  // light-on-light there (1.1:1). Same principle as the home
                  // hero's solid cream pill.
                  child: StatusChip(
                    label: a.status.label,
                    icon: statusIcon(a.status),
                    compact: true,
                    fg: statusFg(a.status, false),
                    bg: statusBg(a.status, false),
                  ),
                ),
              ],
            ),
          ),
          // Info panel: floats fully inside the card, inset from the edges.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(service.name, style: Type.headline(p)),
                            const SizedBox(height: 2),
                            Text(
                              '${pet?.name} · ${staff.name}',
                              style: Type.footnote(p),
                            ),
                          ],
                        ),
                      ),
                      Ic.svg(
                        Ic.chevronRight,
                        color: p.textSecondary,
                        size: 16,
                        stroke: 2.2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusChip(
                        label: mediumDate(a.start),
                        icon: Ic.calendar,
                        compact: true,
                        fg: p.accentText,
                        bg: p.accent.withValues(alpha: 0.12),
                      ),
                      if (service.grooming)
                        StatusChip(
                          label: service.durationLabel,
                          icon: Ic.clock,
                          compact: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: p.divider),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  label: 'Reschedule',
                  icon: Ic.calendar,
                  onTap: () => Navigator.of(context).push(
                    appRoute(
                      BookFlow(
                        initialPetId: a.petId,
                        rebookFrom: a,
                        triage: _triageFor(a),
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 44, color: p.divider),
              Expanded(
                child: _CardAction(
                  label: 'Cancel',
                  icon: Ic.close,
                  destructive: true,
                  onTap: () => _cancel(context),
                ),
              ),
              Container(width: 1, height: 44, color: p.divider),
              Expanded(
                child: _CardAction(
                  label: 'Details',
                  icon: Ic.info,
                  onTap: () => Navigator.of(context).push(
                    appRoute(AppointmentDetailScreen(appointmentId: a.id)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static TriageResult? _triageFor(Appointment a) => a.triageSummary == null
      ? null
      : TriageResult(
          route: TriageRoute.book,
          title: 'Health check',
          summary: a.triageSummary!,
          urgency: a.sickPet ? 1 : 0,
        );

  Future<void> _cancel(BuildContext context) async {
    final ok = await confirmDestructive(
      context,
      title: 'Cancel this appointment?',
      message:
          'Your ${store.serviceOf(appointment.serviceId).name.toLowerCase()} for '
          '${store.pet(appointment.petId)?.name} on ${mediumDate(appointment.start)} will be released. '
          'You can rebook any time.',
      confirmLabel: 'Cancel appointment',
    );
    if (!ok || !context.mounted) return;
    // No follow-up sheet: the card leaving Upcoming and reappearing under Past
    // with a "Cancelled" status is the confirmation. Stacking a second modal on
    // top of the confirmation alert would be needlessly blocking.
    store.cancelAppointment(appointment.id);
  }
}

class PastCard extends StatelessWidget {
  const PastCard({
    super.key,
    required this.appointment,
    required this.store,
    required this.onRebook,
  });

  final Appointment appointment;
  final AppStore store;
  final VoidCallback onRebook;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final pet = store.pet(appointment.petId);
    final service = store.serviceOf(appointment.serviceId);
    final staff = store.staffOf(appointment.staffId);
    final a = appointment;

    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          Navigator.of(context)
              .push(appRoute(AppointmentDetailScreen(appointmentId: a.id))),
      semanticLabel:
          '${pet?.name}, ${service.name}, ${mediumDate(a.start)}, status ${a.status.label}',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                PetArt(
                  seed: (pet?.id.hashCode.abs() ?? 0) % 4,
                  species: pet?.species,
                  radius: 14,
                  iconSize: 38,
                  label: '${pet?.name} portrait',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(service.name, style: Type.headline(p)),
                      const SizedBox(height: 2),
                      Text(
                        '${pet?.name} · ${dayMonth(a.start)} · ${staff.firstName}',
                        style: Type.footnote(p),
                      ),
                    ],
                  ),
                ),
                Text(
                  peso(a.price),
                  style: Type.headline(p).copyWith(color: p.accentText),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: p.divider),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: StatusChip(
                  label: a.status.label,
                  icon: statusIcon(a.status),
                  compact: true,
                  fg: statusFg(a.status, p.isDark),
                  bg: statusBg(a.status, p.isDark),
                ),
              ),
              const Spacer(),
              _CardAction(
                label: 'Rebook',
                icon: Ic.refresh,
                onTap: () => Navigator.of(context).push(
                  appRoute(
                    BookFlow(
                      initialPetId: a.petId,
                      rebookFrom: a,
                      // Rebooking skips triage entirely.
                      triage: null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
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
    final c = destructive ? p.destructive : p.accentText;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          scale: 0.96,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ic.svg(icon, color: c, size: 16, stroke: 2.1),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: Type.footnoteEmph(p).copyWith(color: c),
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
