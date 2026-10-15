import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../data/clinic.dart';
import '../data/seed.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import 'home_screen.dart' show toggleReminderWithSheet;
import '../widgets/common.dart';

/// Reminders — the full settings surface behind Home and Profile → Notifications.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Reminders'),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  SoftCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Ic.svg(Ic.bell, color: p.accent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            store.notificationsAsked
                                ? 'Notifications are allowed for CarePaws.'
                                : 'Notifications are not enabled yet. Turning on your first reminder '
                                      'will ask permission right here.',
                            style: Type.footnote(p),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s16),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < store.reminders.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 54),
                              child: Divider(height: 1, color: p.divider),
                            ),
                          ReminderTile(
                            title: store.reminders[i].title,
                            subtitle: store.reminders[i].subtitle,
                            iconPath: Ic.byName(store.reminders[i].icon),
                            value: store.reminders[i].on,
                            onChanged: (v) => toggleReminderWithSheet(
                              context,
                              store,
                              store.reminders[i].id,
                              v,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s16),
                  Text('Upcoming', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  _UpcomingList(store: store),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final meds = [
      for (final pet in store.pets)
        (
          pet: pet,
          when: '8:00 AM every day',
          what: 'Joint supplement, 1 tablet',
        ),
    ];
    final vaccines = [
      (pet: store.pets.last, when: '9 Jul 2027', what: 'Triose booster'),
    ];
    final appts = [
      for (final a in store.upcoming)
        (
          pet: store.pet(a.petId)!,
          when: mediumDate(a.start),
          what: store.serviceOf(a.serviceId).name,
        ),
    ];

    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final m in meds)
            _ReminderRow(
              icon: Ic.pill,
              title: m.what,
              subtitle: '${m.pet.name} · ${m.when}',
              onTap: () =>
                  _detail(context, m.what, '${m.pet.name} · ${m.when}'),
            ),
          Divider(height: 1, color: p.divider, indent: 54),
          for (final v in vaccines)
            _ReminderRow(
              icon: Ic.syringe,
              title: v.what,
              subtitle: '${v.pet.name} · ${v.when}',
              onTap: () =>
                  _detail(context, v.what, '${v.pet.name} · ${v.when}'),
            ),
          if (appts.isNotEmpty) ...[
            Divider(height: 1, color: p.divider, indent: 54),
            for (final a in appts)
              _ReminderRow(
                icon: Ic.calendar,
                title: a.what,
                subtitle: '${a.pet.name} · ${a.when}',
                onTap: () =>
                    _detail(context, a.what, '${a.pet.name} · ${a.when}'),
              ),
          ],
        ],
      ),
    );
  }

  void _detail(BuildContext context, String title, String when) {
    showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Type.title2(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              when,
              style: Type.body(context.p)
                  .copyWith(color: context.p.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: T.s20),
            PrimaryButton(
              label: 'Done',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RowTile(
      title: title,
      subtitle: subtitle,
      leadingPath: icon,
      onTap: onTap,
    );
  }
}

/// Clinic info: hours, address, emergency contact, nearest after-hours clinic.
class ClinicInfoScreen extends StatelessWidget {
  const ClinicInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final open = clinicOpenAt(store.now);

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Clinic'),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                Seed.clinicName,
                                style: Type.title2(p),
                              ),
                            ),
                            StatusChip(
                              label: open ? 'Open now' : 'Closed now',
                              icon: open ? Ic.checkCircle : Ic.clock,
                              compact: true,
                              fg: open ? p.success : p.warning,
                              bg: open
                                  ? (p.isDark
                                        ? p.success.withValues(alpha: 0.12)
                                        : const Color(0xFFDDF2E3))
                                  : T.amber.withValues(alpha: 0.28),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          clinicStatusLine(store.now),
                          style: Type.footnote(p),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  Text('Hours', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: const [
                        AmountRow(
                          label: 'Monday – Saturday',
                          value: '8:00 AM – 7:00 PM',
                        ),
                        AmountRow(label: 'Sunday', value: '9:00 AM – 4:00 PM'),
                        AmountRow(
                          label: 'Public holidays',
                          value: '9:00 AM – 1:00 PM',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  Text('Visit', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Ic.svg(Ic.pin, color: p.accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                Seed.clinicAddress,
                                style: Type.body(p),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label: 'Open in Maps',
                          icon: Ic.pin,
                          onPressed: () => _openLink(
                            context,
                            Uri.parse(
                              'https://maps.google.com/?q=${Uri.encodeComponent(Clinic.address)}',
                            ),
                            'Open CarePaws in Maps',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  Text('Contact', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        RowTile(
                          title: Seed.clinicPhone,
                          subtitle: 'Reception',
                          leadingPath: Ic.phone,
                          onTap: () =>
                              _call(context, Seed.clinicPhone, Seed.clinicName),
                        ),
                        Divider(height: 1, color: p.divider, indent: 58),
                        RowTile(
                          title: Seed.afterHoursPhone,
                          subtitle: '24-hour animal hospital',
                          leadingPath: Ic.phone,
                          onTap: () => _call(
                            context,
                            Seed.afterHoursPhone,
                            Seed.afterHoursName,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  SoftCard(
                    color: T.amber.withValues(alpha: 0.14),
                    borderColor: p.accent.withValues(alpha: 0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Ic.svg(Ic.alert, color: p.accentText, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'After hours',
                                style: Type.headline(p),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'CarePaws closes at 7:00 PM on weekdays and 4:00 PM on Sundays. '
                          'Outside those hours, go to the nearest 24-hour animal hospital:',
                          style: Type.body(p),
                        ),
                        const SizedBox(height: 10),
                        Text(Seed.afterHoursName, style: Type.headline(p)),
                        const SizedBox(height: 4),
                        Text(
                          Seed.afterHoursPhone,
                          style: Type.body(p).copyWith(color: p.accentText),
                        ),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label:
                              'Call ${Seed.afterHoursName.split(' — ').first}',
                          icon: Ic.phone,
                          destructive: true,
                          onPressed: () => _call(
                            context,
                            Seed.afterHoursPhone,
                            Seed.afterHoursName,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, String number, String name) =>
      callPhoneNumber(context, number: number, name: name);

  Future<void> _openLink(BuildContext context, Uri uri, String title) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!context.mounted) return;
    if (!ok) {
      await showAppSheet(
        context,
        scrollable: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ic.svg(Ic.pin, color: context.p.accent, size: 36),
              const SizedBox(height: 12),
              Text(
                title,
                style: Type.title2(context.p),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                Seed.clinicAddress,
                style: Type.footnote(context.p),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s20),
              PrimaryButton(
                label: 'Done',
                onPressed: () => dismissSheet(context),
              ),
            ],
          ),
        ),
      );
    }
  }
}
