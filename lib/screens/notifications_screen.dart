import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

/// Inbox of clinic notifications.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: 'Notifications',
        showBack: true,
        actions: [
          if (store.unreadNotifications > 0)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 44),
              onPressed: () => store.markNotificationsRead(),
              child: Text(
                'Mark read',
                style: Type.body(p).copyWith(color: p.accentText),
              ),
            ),
        ],
      ),
      child: SafeArea(
        child: store.notifications.isEmpty
            ? EmptyState(
                icon: Ic.bell,
                title: 'Nothing new',
                body: 'Appointment confirmations, grooming updates and prescription renewals land here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                itemCount: store.notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _NotificationCard(
                  notification: store.notifications[i],
                  onTap: () => _open(context, store, store.notifications[i]),
                ),
              ),
      ),
    );
  }

  void _open(BuildContext context, AppStore store, AppNotification n) {
    if (!n.read) {
      store.notifications = store.notifications
          .map((x) => x.id == n.id ? x.copyWith(read: true) : x)
          .toList();
    }
    final target = switch (n.icon) {
      Ic.scissors => ShopsTab(),
      Ic.calendar => const _BookingShortcut(),
      _ => const _InfoShortcut(),
    };
    Navigator.of(context).push(appRoute(target));
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SoftCard(
      onTap: onTap,
      semanticLabel:
          '${notification.title}. ${notification.body}. '
          '${notification.read ? 'Read' : 'Unread'}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: notification.read
                  ? p.fieldBg
                  : T.amber.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Ic.svg(
                notification.icon,
                color: notification.read ? p.textSecondary : p.primaryFill,
                size: 19,
                stroke: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(notification.title, style: Type.headline(p)),
                    ),
                    if (!notification.read)
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(notification.body, style: Type.footnote(p)),
                const SizedBox(height: 6),
                Text(
                  '${shortDate(notification.at)} · ${clockLabel(notification.at)}',
                  style: Type.caption(p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny destinations so a notification tap always lands somewhere real.
class ShopsTab extends StatelessWidget {
  const ShopsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      navigationBar: const DetailNavBar(title: 'Grooming update'),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(T.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ic.svg(Ic.scissors, color: context.p.accent, size: 44),
              const SizedBox(height: T.s16),
              Text('Grooming booking', style: Type.title2(context.p)),
              const SizedBox(height: 8),
              Text(
                'Mochi is booked for a full grooming on Tue 20 Oct at 9:00 AM with Ana Reyes. '
                'Your intake note about the matting behind her ears is attached.',
                style: Type.body(context.p)
                    .copyWith(color: context.p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s24),
              PrimaryButton(
                label: 'Open Shop',
                icon: Ic.bag,
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  store.tab = 3;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingShortcut extends StatelessWidget {
  const _BookingShortcut();

  @override
  Widget build(BuildContext context) {
    final store = AppScope.read(context);
    final a = store.nextAppointment;
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      navigationBar: const DetailNavBar(title: 'Appointment'),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(T.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ic.svg(
                Ic.checkCircle,
                color: context.p.success,
                size: 44,
                stroke: 1.9,
              ),
              const SizedBox(height: T.s16),
              Text('Confirmed', style: Type.title2(context.p)),
              const SizedBox(height: 8),
              Text(
                a == null
                    ? 'You have no upcoming appointments.'
                    : '${store.pet(a.petId)?.name} · ${store.serviceOf(a.serviceId).name}\n'
                          '${mediumDate(a.start)}\nwith ${store.staffOf(a.staffId).name}',
                style: Type.body(context.p)
                    .copyWith(color: context.p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s24),
              PrimaryButton(
                label: 'Open Appointments',
                icon: Ic.calendar,
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  store.tab = 2;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoShortcut extends StatelessWidget {
  const _InfoShortcut();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      navigationBar: const DetailNavBar(title: 'Prescription'),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(T.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ic.svg(Ic.shield, color: context.p.accent, size: 44, stroke: 1.9),
              const SizedBox(height: T.s16),
              Text('Prescription renewed', style: Type.title2(context.p)),
              const SizedBox(height: 8),
              Text(
                'Flea & Tick Spot-On is active for Biscuit until 25 Sep 2027. '
                'Restricted shop items can now be paid for at checkout.',
                style: Type.body(context.p)
                    .copyWith(color: context.p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s24),
              PrimaryButton(
                label: 'OK',
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder reference so the seed clinic name stays imported where used.
const kClinicName = Seed.clinicName;
