import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../data/clinic.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/hero_card.dart';
import '../widgets/promo_carousel.dart';
import 'add_pet_screen.dart';
import 'appointments/appointment_detail_screen.dart';
import 'notifications_screen.dart';
import 'pets/pet_profile_screen.dart';
import 'reminders_screen.dart';
import 'search_screen.dart';
import 'triage_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > 620;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: SafeArea(
        top: true,
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              // 8pt grid: 16pt phone margins (32pt on wide), 8pt top.
              padding: EdgeInsets.fromLTRB(
                wide ? 32 : 16,
                8,
                wide ? 32 : 16,
                40 + TabBarClearance.of(context),
              ),
              sliver: SliverList.list(
                children: [
                  _GreetingRow(store: store),
                  const SizedBox(height: T.s16),
                  PromoCarousel(
                    promos: Seed.promos,
                    onCta: (promo) => _onPromoCta(context, promo),
                  ),
                  const SizedBox(height: T.s16),
                  _NextAppointmentSection(store: store),
                  const SizedBox(height: T.s16),
                  FadeIn(index: 1, child: _QuickActions(store: store)),
                  const SizedBox(height: T.s8),
                  SectionHeader(
                    title: 'My Pets',
                    icon: Ic.paw,
                    actionLabel: store.petCount == 0 ? null : 'Add pet',
                    onAction: store.petCount == 0
                        ? null
                        : () =>
                              Navigator.of(context)
                                  .push(appRoute(const AddPetScreen())),
                  ),
                  if (store.petCount == 0)
                    EmptyState(
                      icon: Ic.byName('paw'),
                      title: 'Add your first pet',
                      body: 'Once your pet is here, you can track visits, vaccines and documents in one place.',
                      actionLabel: 'Add pet',
                      onAction: () =>
                          Navigator.of(context)
                              .push(appRoute(const AddPetScreen())),
                    )
                  else
                    _PetRow(pets: store.pets),
                  const SizedBox(height: T.s8),
                  SectionHeader(
                    title: 'Care reminders',
                    icon: Ic.bell,
                    actionLabel: 'Manage',
                    onAction: () =>
                        Navigator.of(context)
                            .push(appRoute(const RemindersScreen())),
                  ),
                  _RemindersPreview(store: store),
                  const SizedBox(height: T.s8),
                  _ClinicInfoCard(now: store.now),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Good morning, Mark" — the name drops out when the profile has none,
/// so it never reads "Good morning, !".
String _greetingTitle(AppStore store) {
  final g = greetingFor(store.now);
  final first = store.ownerFirstName;
  return first.isEmpty ? g : '$g, $first';
}

/// Greeting row: greeting left, notification + search icons right — one
/// vertically-centered 48pt row. The "Biscuit's visit…" subtitle is gone.
class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SizedBox(
      height: T.tap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _greetingTitle(store),
              style: Type.title2(p),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: T.s8),
          IconTap(
            path: Ic.bell,
            label: 'Notifications, ${store.unreadNotifications} unread',
            badge: store.unreadNotifications,
            color: p.primaryFill,
            onPressed: () =>
                Navigator.of(context)
                    .push(appRoute(const NotificationsScreen())),
          ),
          const SizedBox(width: T.s8),
          IconTap(
            path: Ic.search,
            label: 'Search pets, services and products',
            onPressed: () =>
                Navigator.of(context).push(appRoute(const SearchScreen())),
          ),
        ],
      ),
    );
  }
}

/// Promo CTA destinations. The carousel stays navigation-agnostic; Home owns
/// this map.
void _onPromoCta(BuildContext context, Promo promo) {
  switch (promo.route) {
    case 'shop':
      switchTab(context, 3);
    case 'triage':
      Navigator.of(context)
          .push(appRoute(TriageScreen(entry: TriageEntry.home)));
    case 'book':
    default:
      Navigator.of(context).push(appRoute(const BookLandingScreen()));
  }
}

/// Next appointment as a single HeroCard (G1) — deliberately shorter (16/10)
/// than the 4/3 default so it reads subordinate to the 140pt promo carousel:
/// hierarchy is carousel (color/anchor) → appointment (content) → clinic card
/// (utility). Zero appointments keeps an in-slot EmptyState with a CTA (G3) —
/// no hole in the layout; the section header stays.
class _NextAppointmentSection extends StatelessWidget {
  const _NextAppointmentSection({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final next = store.nextAppointment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Canonical section header: same rhythm as every other section.
        SectionHeader(
          title: 'Next appointment',
          actionLabel: 'View all',
          onAction: () => switchTab(context, 2),
        ),
        if (next == null)
          EmptyState(
            icon: Ic.byName('calendar'),
            title: 'Nothing booked yet',
            body: 'Book a visit and we will handle the reminders.',
            actionLabel: 'Book an appointment',
            onAction: () =>
                Navigator.of(context).push(appRoute(const BookLandingScreen())),
          )
        else
          _AppointmentCard(store: store, appointment: next),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.store, required this.appointment});
  final AppStore store;
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final pet = store.pet(a.petId);
    final service = store.serviceOf(a.serviceId);
    final staff = store.staffOf(a.staffId);
    return Stack(
      children: [
        HeroCard(
          aspectRatio: 16 / 10,
          image: pet == null
              ? PetArt(seed: 1, radius: 0, iconSize: 52)
              : PetAvatar(
                  pet: pet,
                  iconSize: 52,
                  label: '${pet.name} portrait',
                ),
          title: '${service.name} — ${pet?.name ?? 'your pet'}',
          details: [
            _DetailRow(
              icon: Ic.calendar,
              label: '${shortDate(a.start)} · ${clockLabel(a.start)}',
            ),
            _DetailRow(icon: Ic.person, label: staff.name),
          ],
          onTap: () =>
              Navigator.of(context)
                  .push(appRoute(AppointmentDetailScreen(appointmentId: a.id))),
        ),
        // Countdown chip overlaid top-right of the image (s12 inset) —
        // inside the image area, never competing with the panel.
        Positioned(
          top: 12,
          right: 12,
          child: StatusChip(
            label: countdownLabel(store.now, a.start),
            icon: Ic.clock,
            compact: true,
            // Solid amber with espresso text (8.80:1, photo-independent):
            // over an arbitrary photo a translucent tint can't guarantee
            // 4.5:1 — the one sanctioned text-on-amber use.
            fg: T.espresso,
            bg: T.amber,
          ),
        ),
      ],
    );
  }
}

/// Key-detail row for HeroCard panels: 12pt icon + footnote label, wrapping
/// to 2 lines max.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Ic.svg(icon, size: 12, color: p.textSecondary, stroke: 2),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Type.footnote(p).copyWith(color: p.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Clinic info card (G2): collapsed to the essentials — clinic name,
/// open/closed status with today's hours — tap expands the full info
/// (address, phone, full schedule). Replaces the old always-expanded card;
/// nothing here duplicates ClinicInfoScreen.
class _ClinicInfoCard extends StatefulWidget {
  const _ClinicInfoCard({required this.now});
  final DateTime now;

  @override
  State<_ClinicInfoCard> createState() => _ClinicInfoCardState();
}

class _ClinicInfoCardState extends State<_ClinicInfoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final reduce = reduceMotionOf(context);
    final open = clinicOpenAt(widget.now);
    // AX5: the 76pt toggle cannot fit 3.2x name + status text — grow it with
    // Dynamic Type instead of clipping, like the promo cards.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final toggleH = 76.0 * scale.clamp(1.0, 1.6);

    // Expanded details body, shared by the animated and reduced-motion paths.
    final Widget details = _expanded
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: T.s12),
                _ClinicRow(
                  icon: Ic.pin,
                  label: Seed.clinicAddress,
                  onTap: () => _openMaps(context),
                ),
                _ClinicRow(
                  icon: Ic.phone,
                  label: Seed.clinicPhone,
                  accent: true,
                  onTap: () => callPhoneNumber(
                    context,
                    number: Seed.clinicPhone,
                    name: Seed.clinicName,
                  ),
                ),
                const SizedBox(height: T.s8),
                Divider(height: 1, color: p.divider),
                const SizedBox(height: T.s8),
                Text(
                  'Hours',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: T.s4),
                for (var i = 0; i < 7; i++)
                  _HoursRow(
                    weekday: i + 1,
                    isToday: widget.now.weekday == i + 1,
                  ),
                // After-hours fallback: kept from the previous card — urgent
                // concerns outside clinic hours need a visible answer.
                const SizedBox(height: 12),
                _AfterHoursNote(onCall: () => _callAfterHours(context)),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(T.rCard),
        boxShadow: p.isDark
            ? null
            : const [
                BoxShadow(
                  color: T.shadowLight,
                  blurRadius: T.shadowBlur,
                  offset: Offset(0, T.shadowDy),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle row: the 76pt header is one tap target.
          Semantics(
            button: true,
            label:
                'Clinic information, ${_expanded ? 'expanded' : 'collapsed'}. '
                '${clinicStatusLine(widget.now)}',
            child: ExcludeSemantics(
              child: PressScale(
                onTap: () => setState(() => _expanded = !_expanded),
                child: SizedBox(
                  height: toggleH,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Seed.clinicName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: p.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: open ? p.success : T.destructive,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      clinicStatusLine(widget.now),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: p.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: reduce
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          child: Ic.svg(
                            Ic.chevronDown,
                            size: 20,
                            color: T.taupe,
                            stroke: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Expanded details animate open over the house spring. Under
          // reduced motion the AnimatedSize is skipped entirely — a
          // zero-duration AnimatedSize completes its controller inside
          // performLayout and throws ("mutated in its own performLayout").
          reduce
              ? details
              : AnimatedSize(
                  duration: const Duration(milliseconds: T.springMs),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: details,
                ),
        ],
      ),
    );
  }
}

/// Tappable clinic row (address, phone): 15pt label, ≥44pt target.
class _ClinicRow extends StatelessWidget {
  const _ClinicRow({
    required this.icon,
    required this.label,
    this.accent = false,
    this.onTap,
  });
  final String icon;
  final String label;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Ic.svg(
                  icon,
                  size: 18,
                  color: accent ? T.terracottaText : p.textSecondary,
                  stroke: 1.9,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: accent ? T.terracottaText : p.text,
                    ),
                    maxLines: 2,
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

/// One schedule row: day left, hours right, today highlighted.
class _HoursRow extends StatelessWidget {
  const _HoursRow({required this.weekday, required this.isToday});
  final int weekday; // 1 = Monday … 7 = Sunday
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
      color: isToday ? T.terracottaDeep : p.textSecondary,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(child: Text(Clinic.weekdayName(weekday), style: style)),
          Text(
            weekday == DateTime.sunday ? 'Closed' : Clinic.hoursRangeLabel,
            style: style,
          ),
        ],
      ),
    );
  }
}

/// After-hours emergency callout: amber banner with the 24-hour hospital.
// Tapping calls it — urgent concerns outside clinic hours get an answer,
// never a dead end.
class _AfterHoursNote extends StatelessWidget {
  const _AfterHoursNote({required this.onCall});
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      label:
          'After hours emergency: call ${Seed.afterHoursName}, ${Seed.afterHoursPhone}',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onCall,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: T.amber.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Ic.svg(Ic.alert, color: p.warning, size: 17),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'After hours, the nearest 24-hour animal hospital is ${Seed.afterHoursName} · ${Seed.afterHoursPhone}',
                    style: Type.footnote(p).copyWith(color: p.warning),
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

/// Dials the after-hours emergency hospital.
void _callAfterHours(BuildContext context) => callPhoneNumber(
  context,
  number: Seed.afterHoursPhone,
  name: Seed.afterHoursName,
);

/// Opens the clinic address in Maps; falls back to showing the address
/// itself when no maps app is available — never a dead end.
Future<void> _openMaps(BuildContext context) async {
  final uri = Uri.parse(
    'https://maps.google.com/?q=${Uri.encodeComponent(Clinic.address)}',
  );
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!context.mounted) return;
  if (!ok) {
    await showPopup<void>(
      context,
      centered: true,
      barrierDismissible: true,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('CarePaws Veterinary Clinic'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(Clinic.address),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 560;
    final actions = [
      (
        label: 'Book',
        icon: Ic.calendar,
        onTap: () =>
            Navigator.of(context).push(appRoute(const BookLandingScreen())),
      ),
      (
        label: 'AI Triage',
        icon: Ic.sparkle,
        onTap: () =>
            Navigator.of(context)
                .push(appRoute(TriageScreen(entry: TriageEntry.home))),
      ),
      (
        label: 'Chat',
        icon: Ic.chat,
        onTap: () =>
            Navigator.of(context).push(appRoute(const ChatLandingScreen())),
      ),
    ];
    // Height grows with Dynamic Type so tiles never clip their labels.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final h = 116 * scale.clamp(1.0, 1.6);
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _QuickAction(
          label: actions[i].label,
          icon: actions[i].icon,
          onTap: actions[i].onTap,
          width: wide ? 130 : 112 * scale.clamp(1.0, 1.4),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.width = 112,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Container(
            width: width,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon in a tinted circle medallion — more designed than the
                // bare icon, and the 48pt circle is its own touch target.
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Ic.svg(icon, color: p.accent, size: 24, stroke: 1.9),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    label,
                    style: Type.footnoteEmph(p),
                    textAlign: TextAlign.center,
                    maxLines: 2,
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

class _PetRow extends StatelessWidget {
  const _PetRow({required this.pets});
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: pets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final pet = pets[i];
          return Semantics(
            button: true,
            label:
                '${pet.name}, ${pet.breed}, ${pet.ageLabel}. Open pet profile',
            child: ExcludeSemantics(
              child: PressScale(
                onTap: () =>
                    Navigator.of(context)
                        .push(appRoute(PetProfileScreen(petId: pet.id))),
                child: SizedBox(
                  width: 148,
                  height: 188,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(T.rCard),
                    child: Stack(
                      children: [
                        // Full-bleed pet photo. No photo → seeded art with the
                        // medallion optically centred in the visible area
                        // above the name/scrim, not the geometric centre.
                        Positioned.fill(
                          child: PetAvatar(
                            pet: pet,
                            iconSize: 54,
                            alignment: const Alignment(0.0, -0.35),
                            label: '${pet.name} portrait',
                          ),
                        ),
                        // Bottom scrim so the cream text stays readable.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 96,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF000000).withValues(alpha: 0),
                                  // 0.72: script-verified ≥4.5:1 for the cream
                                  // name AND the 75%-cream subtitle over the
                                  // worst case (a white photo).
                                  const Color(0xFF000000)
                                      .withValues(alpha: 0.72),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Species pill, top-left — glass over the photo.
                        Positioned(
                          left: 10,
                          top: 10,
                          child: GlassPill(
                            label: pet.species == Species.dog ? 'Dog' : 'Cat',
                          ),
                        ),
                        // Name + age/weight, bottom-left over the scrim.
                        Positioned(
                          left: 10,
                          right: 36,
                          bottom: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pet.name,
                                style: Type.headline(p)
                                    .copyWith(color: T.cream),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${pet.ageLabel} · ${pet.weightKg} kg',
                                style: Type.caption(p).copyWith(
                                  color: T.cream.withValues(alpha: 0.75),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Chevron affordance, bottom-right over the scrim.
                        Positioned(
                          right: 10,
                          bottom: 12,
                          child: Ic.svg(
                            Ic.chevronRight,
                            color: T.cream,
                            size: 16,
                            stroke: 2.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// First three reminders inline, each with a Terracotta switch. The first
/// toggle-on raises the in-context notification permission sheet.
class _RemindersPreview extends StatelessWidget {
  const _RemindersPreview({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final shown = store.reminders.take(3).toList();
    // G3: an empty list shows a call to action, never blank space.
    if (shown.isEmpty) {
      return EmptyState(
        compact: true,
        icon: Ic.byName('bell'),
        title: 'No reminders yet',
        body: 'We will nudge you about medications, vaccines and visits.',
        actionLabel: 'Add a reminder',
        onAction: () =>
            Navigator.of(context).push(appRoute(const RemindersScreen())),
      );
    }
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 54),
                child: Divider(height: 1, color: p.divider),
              ),
            ReminderTile(
              title: shown[i].title,
              subtitle: shown[i].subtitle,
              iconPath: shown[i].icon,
              value: shown[i].on,
              onChanged: (v) =>
                  toggleReminderWithSheet(context, store, shown[i].id, v),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared toggle handler: the very first switch-on asks for notification
/// permission in context, then reflects the granted state.
Future<void> toggleReminderWithSheet(
  BuildContext context,
  AppStore store,
  String id,
  bool value,
) async {
  if (value && !store.notificationsAsked) {
    final granted = await showNotificationPermissionSheet(context);
    store.setNotificationsAsked(granted);
    if (!granted) {
      store.toggleReminder(id, false);
      if (context.mounted) {
        await showPopup<void>(
          context,
          centered: true,
          barrierDismissible: false,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Reminders stay off'),
            content: const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Notifications are turned off for CarePaws, so reminders cannot reach you. '
                'You can enable them later in Settings › Notifications.',
              ),
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => dismissSheet(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
  }
  store.toggleReminder(id, value);
}

/// In-context notification permission sheet (shown at the moment it matters).
Future<bool> showNotificationPermissionSheet(BuildContext context) async {
  final result = await showPopup<bool>(
    context,
    builder: (ctx) => CupertinoActionSheet(
      title: const Text('Turn on reminders?'),
      message: Text(
        'CarePaws will remind you about medications, vaccine dates, appointments and grooming rebooks. '
        'You can change this any time in Profile › Notifications.',
      ),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Allow notifications'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(ctx).pop(false),
        child: const Text('Not now'),
      ),
    ),
  );
  return result ?? false;
}

/// Switches to another tab and pops this tab's route stack back to its root.
void switchTab(BuildContext context, int index) {
  final store = AppScope.read(context);
  store.tab = index;
  Navigator.of(context).popUntil((r) => r.isFirst);
}

// -------------------------------------------------------- tab landing pages

/// Reached from Home quick actions — jumps to the Appointments tab.
class BookLandingScreen extends StatelessWidget {
  const BookLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      navigationBar: const DetailNavBar(title: 'Book'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(T.s20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Choose a service to get started',
                style: Type.title2(context.p),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Pets are pre-selected, and the triage step is optional.',
                style: Type.body(context.p)
                    .copyWith(color: context.p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s24),
              PrimaryButton(
                label: 'Open Appointments',
                icon: Ic.calendar,
                onPressed: () => switchTab(context, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatLandingScreen extends StatelessWidget {
  const ChatLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      navigationBar: const DetailNavBar(title: 'Chat'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(T.s20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Two threads, one inbox',
                style: Type.title2(context.p),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'CarePaws AI answers instantly; the clinic team replies during clinic hours.',
                style: Type.body(context.p)
                    .copyWith(color: context.p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s24),
              PrimaryButton(
                label: 'Open Chats',
                icon: Ic.chat,
                onPressed: () => switchTab(context, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShopLandingScreen extends StatelessWidget {
  const ShopLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      navigationBar: const DetailNavBar(title: 'Shop'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(T.s20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pickup at the clinic',
                style: Type.title2(context.p),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'No delivery — collect your order at the clinic counter.',
                style: Type.body(context.p)
                    .copyWith(color: context.p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s24),
              PrimaryButton(
                label: 'Open Shop',
                icon: Ic.bag,
                onPressed: () => switchTab(context, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
