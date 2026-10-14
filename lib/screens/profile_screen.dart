import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../data/seed.dart';
import '../data/models.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../services/ai_service.dart' show AiStatus;
import '../state/app_store.dart';
import '../widgets/common.dart';
import 'profile/privacy_screen.dart';
import 'reminders_screen.dart';
import 'profile/settings_screens.dart';
import 'shop/orders_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Profile'),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              40 + TabBarClearance.of(context),
            ),
            sliver: SliverList.list(
              children: [
                // The settings action lives on the header's trailing edge next to
                // the chevron, so it costs no extra row above the fold.
                SoftCard(
                  onTap: () =>
                      Navigator.of(context)
                          .push(appRoute(const EditProfileScreen())),
                  semanticLabel:
                      '${store.ownerName}. ${Seed.ownerContact}. Tap to edit your profile',
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: p.accent.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: OwnerAvatar(
                          initials: initialsOf(store.ownerName),
                          size: 62,
                          photo: store.ownerPhoto,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(store.ownerName, style: Type.title2(p)),
                            const SizedBox(height: 3),
                            Text(Seed.ownerContact, style: Type.footnote(p)),
                            const SizedBox(height: 6),
                            StatusChip(
                              label:
                                  '${store.petCount} pets · ${store.upcoming.length} upcoming',
                              icon: Ic.paw,
                              compact: true,
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
                      const SizedBox(width: 2),
                      IconTap(
                        path: Ic.settings,
                        label: 'Settings',
                        color: p.primaryFill,
                        onPressed: () =>
                            Navigator.of(context)
                                .push(appRoute(const SettingsScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: T.s20),

                Text('Activity', style: Type.headline(p)),
                const SizedBox(height: 10),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      RowTile(
                        title: 'My orders',
                        subtitle: store.orders.isEmpty
                            ? 'No orders yet'
                            : '${store.orders.length} orders · ${peso(store.orders.fold(0.0, (a, o) => a + o.total))} lifetime',
                        leadingPath: Ic.bag,
                        onTap: () =>
                            Navigator.of(context)
                                .push(appRoute(const OrdersScreen())),
                      ),
                      Divider(height: 1, color: p.divider, indent: 58),
                      RowTile(
                        title: 'Prescriptions',
                        subtitle: store.prescriptions.isEmpty
                            ? 'None on file'
                            : '${store.prescriptions.length} active · signed by ${store.prescriptions.first.vetName}',
                        leadingPath: Ic.shield,
                        onTap: () => _prescriptions(context, store),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: T.s20),

                Text('Settings', style: Type.headline(p)),
                const SizedBox(height: 10),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      RowTile(
                        title: 'CarePaws AI',
                        subtitle: store.ai.isLive
                            ? 'Live · ${store.ai.modelLabel}'
                            : store.ai.status == AiStatus.checking
                            ? 'Checking for a key…'
                            : 'Unavailable · tap to add a key',
                        leadingPath: Ic.sparkle,
                        onTap: () =>
                            Navigator.of(context)
                                .push(appRoute(const AiSettingsScreen())),
                      ),
                      Divider(height: 1, color: p.divider, indent: 58),
                      RowTile(
                        title: 'Notifications',
                        subtitle:
                            store.reminderOn(ReminderKind.medication) ||
                                store.reminderOn(ReminderKind.vaccine)
                            ? 'Reminders on'
                            : 'All reminders off',
                        leadingPath: Ic.bell,
                        onTap: () =>
                            Navigator.of(context)
                                .push(appRoute(const RemindersScreen())),
                      ),
                      Divider(height: 1, color: p.divider, indent: 58),
                      RowTile(
                        title: 'Language',
                        subtitle: store.language,
                        leadingPath: Ic.globe,
                        onTap: () =>
                            Navigator.of(context)
                                .push(appRoute(const LanguageScreen())),
                      ),
                      Divider(height: 1, color: p.divider, indent: 58),
                      RowTile(
                        title: 'Appearance',
                        subtitle: store.themeMode.label,
                        leadingPath: store.darkMode ? Ic.moon : Ic.sun,
                        onTap: () =>
                            Navigator.of(context)
                                .push(appRoute(const AppearanceScreen())),
                      ),
                      Divider(height: 1, color: p.divider, indent: 58),
                      RowTile(
                        title: 'Privacy',
                        subtitle: 'Export data, delete account',
                        leadingPath: Ic.lock,
                        onTap: () =>
                            Navigator.of(context)
                                .push(appRoute(const PrivacyScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: T.s20),

                Text('Support', style: Type.headline(p)),
                const SizedBox(height: 10),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      RowTile(
                        title: 'Help centre',
                        subtitle: 'Guides for booking, orders and records',
                        leadingPath: Ic.info,
                        onTap: () =>
                            Navigator.of(context)
                                .push(appRoute(const HelpScreen())),
                      ),
                      Divider(height: 1, color: p.divider, indent: 58),
                      RowTile(
                        title: 'Contact clinic',
                        subtitle: Seed.clinicPhone,
                        leadingPath: Ic.phone,
                        onTap: () => _contactClinic(context),
                      ),
                      Divider(height: 1, color: p.divider, indent: 58),
                      RowTile(
                        title: 'FAQs',
                        subtitle: 'Answers about visits, vaccines and pickup',
                        leadingPath: Ic.doc,
                        onTap: () =>
                            Navigator.of(context)
                                .push(appRoute(const FaqScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: T.s20),

                Text('About', style: Type.headline(p)),
                const SizedBox(height: 10),
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      RowTile(
                        title: 'Terms of service',
                        leadingPath: Ic.doc,
                        onTap: () => Navigator.of(context).push(
                          appRoute(const LegalScreen(kind: LegalKind.terms)),
                        ),
                      ),
                      Divider(height: 1, color: p.divider, indent: 58),
                      RowTile(
                        title: 'Privacy policy',
                        leadingPath: Ic.lock,
                        onTap: () => Navigator.of(context).push(
                          appRoute(const LegalScreen(kind: LegalKind.privacy)),
                        ),
                      ),
                      Divider(height: 1, color: p.divider, indent: 58),
                      RowTile(
                        title: 'App version',
                        subtitle: Seed.appVersion,
                        leadingPath: Ic.info,
                        showChevron: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: T.s20),
                PrimaryButton(
                  label: 'Log out',
                  icon: Ic.logout,
                  destructive: true,
                  onPressed: () => _logout(context),
                ),
                const SizedBox(height: T.s16),
                Center(
                  child: Text(
                    'CarePaws Veterinary Clinic',
                    style: Type.caption(p),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _prescriptions(BuildContext context, AppStore store) {
    showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Digital prescriptions', style: Type.title1(context.p)),
            const SizedBox(height: 6),
            Text(
              'Signed by the veterinarian. Restricted shop items check this list at checkout.',
              style: Type.footnote(context.p),
            ),
            const SizedBox(height: T.s16),
            for (final rx in store.prescriptions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Ic.svg(Ic.shield, color: context.p.accent, size: 18),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              store.productOf(rx.productId).name,
                              style: Type.headline(context.p),
                            ),
                          ),
                          StatusChip(
                            label: rx.activeAt(store.now)
                                ? 'Active'
                                : 'Expired',
                            compact: true,
                            fg: rx.activeAt(store.now)
                                ? context.p.success
                                : context.p.destructive,
                            bg: rx.activeAt(store.now)
                                ? const Color(0xFFDDF2E3)
                                : const Color(0x1FDC2626),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Signed by ${rx.vetName} · valid until ${shortDate(rx.expires)} · ${rx.refills} refills',
                        style: Type.footnote(context.p),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: T.s12),
            PrimaryButton(
              label: 'Done',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contactClinic(BuildContext context) async {
    await showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contact the clinic', style: Type.title2(context.p)),
            const SizedBox(height: 10),
            Text(
              Seed.clinicPhone,
              style: Type.largeTitle(context.p)
                  .copyWith(color: context.p.accentText),
            ),
            const SizedBox(height: 8),
            Text(
              Seed.clinicHours,
              style: Type.footnote(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'After hours: ${Seed.afterHoursName}\n${Seed.afterHoursPhone}',
              style: Type.footnote(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: T.s20),
            PrimaryButton(
              label: 'Open chats',
              icon: Ic.chat,
              onPressed: () {
                dismissSheet(context);
                AppScope.read(context).tab = 1;
              },
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Close',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDestructive(
      context,
      title: 'Log out of CarePaws?',
      message: 'Your pets, appointments and orders stay on your account. You can log back in any time.',
      confirmLabel: 'Log out',
    );
    if (!ok || !context.mounted) return;
    if (!context.mounted) return;
    dismissSheet(context);
    if (!context.mounted) return;
    await showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic.svg(
              Ic.checkCircle,
              color: context.p.success,
              size: 40,
              stroke: 1.9,
            ),
            const SizedBox(height: 12),
            Text(
              'Signed out',
              style: Type.title2(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This is a prototype build, so the session stays open. Log back in to continue.',
              style: Type.body(context.p)
                  .copyWith(color: context.p.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: T.s20),
            PrimaryButton(
              label: 'Log back in',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}
