import 'package:flutter/cupertino.dart';

import '../../app.dart' show DetailNavBar, LargeTitleBar, appRoute;
import '../../data/clinic.dart';
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import '../profile/settings_screens.dart'
    show AiSettingsScreen, AppearanceScreen;
import 'comms_screen.dart';

/// MORE — the vet portal's overflow tab: AI comms composer, inventory,
/// clinic settings, staff settings (Task 7).
///
/// Reuses the customer settings components where they fit ([AppearanceScreen]
/// and [AiSettingsScreen] are the same screens the customer sees — the AI
/// the composer drafts with is configured there), and the shared [RowTile]
/// rows. Clinic facts come from [Clinic], the single source of truth.
class VetMoreScreen extends StatelessWidget {
  const VetMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final lowStock = store.products.where((pr) => pr.stock <= 5).length;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'More'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, T.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _groupTitle(p, 'Messages'),
                  const SizedBox(height: T.s8),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: RowTile(
                      title: 'AI comms composer',
                      subtitle: 'Draft, approve and send announcements',
                      leadingPath: Ic.sparkle,
                      onTap: () =>
                          Navigator.of(context)
                              .push(appRoute(const CommsScreen())),
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  _groupTitle(p, 'Inventory'),
                  const SizedBox(height: T.s8),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: RowTile(
                      title: 'Products & stock',
                      subtitle:
                          '${store.products.length} products · $lowStock low on stock',
                      leadingPath: Ic.bag,
                      onTap: () =>
                          Navigator.of(context)
                              .push(appRoute(const VetInventoryScreen())),
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  _groupTitle(p, 'Clinic'),
                  const SizedBox(height: T.s8),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        RowTile(
                          title: 'Clinic settings',
                          subtitle: Clinic.hoursLabel,
                          leadingPath: Ic.home,
                          onTap: () =>
                              Navigator.of(context)
                                  .push(appRoute(const ClinicSettingsScreen())),
                        ),
                        Divider(height: 1, color: p.divider, indent: 58),
                        RowTile(
                          title: 'Staff',
                          subtitle: '${Seed.staff.length} team members',
                          leadingPath: Ic.person,
                          onTap: () =>
                              Navigator.of(context)
                                  .push(appRoute(const StaffSettingsScreen())),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: TabBarClearance.of(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTitle(AppPalette p, String title) =>
      Text(title, style: Type.headline(p));
}

/// Stock levels, read from the existing product data ([AppStore.products] ←
/// [Seed.products]). Read-only: restocking is a backend/shop task.
class VetInventoryScreen extends StatelessWidget {
  const VetInventoryScreen({super.key});

  /// "Low on stock" threshold. Local to this screen — the shop never
  /// defined one.
  static const lowStockAt = 5;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final products = store.products;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Products & stock'),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(T.s16, T.s12, T.s16, 40),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(height: T.s12),
          itemBuilder: (context, i) {
            final pr = products[i];
            final low = pr.stock <= lowStockAt;
            return SoftCard(
              padding: const EdgeInsets.all(T.s16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(T.rControl),
                    ),
                    child: Center(
                      child: Ic.svg(
                        Ic.byName(pr.icon),
                        color: p.accent,
                        size: 22,
                        stroke: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: T.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pr.name,
                          style: Type.headline(p),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${pr.price.toStringAsFixed(0)}',
                          style: Type.footnote(p)
                              .copyWith(color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: T.s8),
                  StatusChip(
                    label: pr.stock == 0
                        ? 'Out of stock'
                        : low
                        ? '${pr.stock} left'
                        : 'In stock · ${pr.stock}',
                    compact: true,
                    fg: pr.stock == 0
                        ? const Color(0xFFDC2626)
                        : low
                        ? p.accentText
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Clinic settings. Hours, address and contact read from [Clinic] (the
/// single source of truth) — read-only for now; editing them is a backend
/// task. Appearance and the AI providers reuse the customer settings
/// screens: the composer drafts with the AI configured there.
class ClinicSettingsScreen extends StatelessWidget {
  const ClinicSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Clinic settings'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(T.s20, T.s16, T.s20, 40),
          children: [
            Text('Clinic', style: Type.headline(p)),
            const SizedBox(height: T.s8),
            SoftCard(
              padding: const EdgeInsets.all(T.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Clinic.name, style: Type.headline(p)),
                  const SizedBox(height: 6),
                  _fact(p, Ic.clock, Clinic.hoursLabel),
                  const SizedBox(height: 6),
                  _fact(p, Ic.pin, Clinic.address),
                  const SizedBox(height: 6),
                  _fact(p, Ic.phone, Clinic.phone),
                  const SizedBox(height: T.s12),
                  Text(
                    'Hours, address and contact are managed in the backend — '
                    'shown here read-only.',
                    style: Type.footnote(p).copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: T.s20),
            Text('App', style: Type.headline(p)),
            const SizedBox(height: T.s8),
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
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
                    title: 'CarePaws AI',
                    subtitle: store.ai.isLive
                        ? 'Live · ${store.ai.modelLabel}'
                        : 'Unavailable — add a key',
                    leadingPath: Ic.sparkle,
                    onTap: () =>
                        Navigator.of(context)
                            .push(appRoute(const AiSettingsScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fact(AppPalette p, String icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Ic.svg(icon, color: p.textSecondary, size: 15, stroke: 2),
      ),
      const SizedBox(width: T.s8),
      Expanded(child: Text(text, style: Type.footnote(p))),
    ],
  );
}

/// Staff settings: who is on the team. Read-only directory — the spec keeps
/// two roles only (customer, vet) with no staff sub-role permissions in the
/// portal, so there is nothing to configure per person.
class StaffSettingsScreen extends StatelessWidget {
  const StaffSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final staff = Seed.staff;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Staff'),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(T.s16, T.s12, T.s16, 40),
          itemCount: staff.length,
          separatorBuilder: (_, _) => const SizedBox(height: T.s12),
          itemBuilder: (context, i) {
            final member = staff[i];
            return SoftCard(
              padding: const EdgeInsets.all(T.s16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        member.initials,
                        textScaler: TextScaler.noScaling,
                        style: Type.headline(p).copyWith(color: p.accentText),
                      ),
                    ),
                  ),
                  const SizedBox(width: T.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          member.name,
                          style: Type.headline(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${member.role.label} · ${member.focus}',
                          style: Type.footnote(p)
                              .copyWith(color: p.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
