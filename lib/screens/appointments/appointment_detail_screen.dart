import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import '../appointments_screen.dart' show statusBg, statusFg, statusIcon;
import 'book_flow.dart';

class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});
  final String appointmentId;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final a = store.appt(appointmentId);

    if (a == null) {
      return CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: const DetailNavBar(title: 'Appointment'),
        child: const EmptyState(
          icon: Ic.calendar,
          title: 'Appointment not found',
          body: 'It may have been removed. Head back to Appointments to see your current bookings.',
        ),
      );
    }

    final pet = store.pet(a.petId);
    final service = store.serviceOf(a.serviceId);
    final staff = store.staffOf(a.staffId);
    final isPast = !a.status.isActive;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: service.name,
        actions: [
          if (a.status == ApptStatus.readyForPickup)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: StatusChip(
                  label: 'Ready',
                  icon: Ic.gift,
                  compact: true,
                  fg: p.warning,
                  bg: const Color(0xFFFDE3C7),
                ),
              ),
            ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  // Hero with floating glass info card.
                  SizedBox(
                    height: Layout.heroHeight(context, 210),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(T.rCard),
                            child: PetArt(
                              seed: (pet?.id.hashCode.abs() ?? 0) % 4,
                              species: pet?.species,
                              iconSize: 120,
                              label: '${pet?.name} portrait',
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: -34,
                          child: GlassCard(
                            padding: const EdgeInsets.all(T.s16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${pet?.name} · ${service.name}',
                                  style: Type.title2(p),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  mediumDate(a.start),
                                  style: Type.body(p).copyWith(color: p.textSecondary),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatusChip(
                                      label: a.status.label,
                                      icon: statusIcon(a.status),
                                      compact: true,
                                      fg: statusFg(a.status, p.isDark),
                                      bg: statusBg(a.status, p.isDark),
                                    ),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text('Assigned staff', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Row(
                      children: [
                        StaffAvatar(initials: staff.initials, size: 48, role: staff.role),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(staff.name, style: Type.headline(p)),
                              const SizedBox(height: 2),
                              Text(
                                '${staff.role.label} · ${staff.years} years',
                                style: Type.footnote(p),
                              ),
                              const SizedBox(height: 2),
                              Text(staff.focus, style: Type.caption(p)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  Text('Visit details', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [
                        AmountRow(label: 'Date', value: shortDate(a.start), bold: true),
                        AmountRow(label: 'Time', value: clockLabel(a.start), bold: true),
                        AmountRow(
                          label: 'Ends',
                          value: clockLabel(a.end),
                        ),
                        AmountRow(label: 'Total', value: peso(a.price), bold: true),
                        if (a.sickPet)
                          const Padding(
                            padding: EdgeInsets.only(top: 8, bottom: 4),
                            child: _InfoRow(
                              icon: Ic.stethoscope2,
                              text: 'Sick-visit request — confirmed by the vet assistant',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (service.grooming && a.grooming != null) ...[
                    const SizedBox(height: T.s20),
                    Text('Grooming intake', style: Type.headline(p)),
                    const SizedBox(height: 10),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(
                        children: [
                          AmountRow(label: 'Size', value: a.grooming!.size),
                          AmountRow(label: 'Coat condition', value: a.grooming!.coat),
                          if (a.grooming!.notes.isNotEmpty)
                            AmountRow(label: 'Notes', value: a.grooming!.notes),
                        ],
                      ),
                    ),
                  ],
                  if (a.triageSummary != null) ...[
                    const SizedBox(height: T.s20),
                    Text('Health check', style: Type.headline(p)),
                    const SizedBox(height: 10),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Ic.svg(Ic.sparkle, color: p.accent, size: 18),
                              const SizedBox(width: 8),
                              Text('Guidance, not a diagnosis', style: Type.footnoteEmph(p)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(a.triageSummary!, style: Type.body(p)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: T.s20),
                  Text('Where', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Ic.svg(Ic.location2, color: p.accent, size: 20),
                            const SizedBox(width: 9),
                            Expanded(child: Text(Seed.clinicName, style: Type.headline(p))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(Seed.clinicAddress, style: Type.footnote(p)),
                        const SizedBox(height: 6),
                        Text(Seed.clinicPhone, style: Type.footnote(p)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isPast)
              StickyCta(
                child: Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Cancel',
                        destructive: true,
                        onPressed: () => _cancel(context, a),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: 'Reschedule',
                        icon: Ic.calendar,
                        onPressed: () => Navigator.of(context).pushReplacement(
                          appRoute(BookFlow(initialPetId: a.petId, rebookFrom: a)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              StickyCta(
                child: PrimaryButton(
                  label: 'Rebook this visit',
                  icon: Ic.refresh,
                  onPressed: () => Navigator.of(context).pushReplacement(
                    appRoute(BookFlow(initialPetId: a.petId, rebookFrom: a)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, Appointment a) async {
    final store = AppScope.read(context);
    final ok = await confirmDestructive(
      context,
      title: 'Cancel this appointment?',
      message:
          '${store.pet(a.petId)?.name}’s ${store.serviceOf(a.serviceId).name.toLowerCase()} '
          'on ${mediumDate(a.start)} will be released.',
      confirmLabel: 'Cancel appointment',
    );
    if (!ok || !context.mounted) return;
    store.cancelAppointment(a.id);
    if (!context.mounted) return;
    dismissSheet(context);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Ic.svg(icon, color: p.accent, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Type.footnote(p))),
      ],
    );
  }
}

/// Booking success sheet: "Add to Calendar" + "Done".
Future<void> showBookingSuccessSheet(
  BuildContext context, {
  required Appointment appointment,
  required String petName,
}) async {
  final store = AppScope.read(context);
  var added = false;
  await showAppSheet(
    context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0x1FDDF2E3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Ic.svg(
                  appointment.status == ApptStatus.requestPending ? Ic.clock : Ic.checkCircle,
                  color: appointment.status == ApptStatus.requestPending
                      ? context.p.warning
                      : context.p.success,
                  size: 36,
                  stroke: 2,
                ),
              ),
            ),
            const SizedBox(height: T.s16),
            Text(
              appointment.status == ApptStatus.requestPending
                  ? 'Request sent'
                  : 'Booking confirmed',
              style: Type.title1(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$petName · ${mediumDate(appointment.start)}\n${store.staffOf(appointment.staffId).name}',
              style: Type.body(context.p).copyWith(color: context.p.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (appointment.status == ApptStatus.requestPending) ...[
              const SizedBox(height: 12),
              Text(
                'The vet assistant will confirm this visit during clinic hours.',
                style: Type.footnote(context.p),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: T.s24),
            PrimaryButton(
              label: added ? 'Added to Calendar' : 'Add to Calendar',
              icon: added ? Ic.check : Ic.calendar,
              onPressed: () {
                added = true;
                successHaptic();
                setSheet(() {});
              },
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Done',
              onPressed: () => dismissSheet(ctx),
            ),
          ],
        ),
      ),
    ),
  );
}