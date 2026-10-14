import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/nav_actions.dart';
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
      child: CustomScrollView(
        slivers: [
          LargeTitleBar(title: greetingFor(store.now)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              wide ? 32 : 20,
              12,
              wide ? 32 : 20,
              40 + TabBarClearance.of(context),
            ),
            sliver: SliverList.list(
              children: [
                // Title line and its actions share one row — the actions used to
                // sit on a row of their own, which cost ~52pt above the fold.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        greetingSub(store.now),
                        style: Type.body(p).copyWith(color: p.textSecondary),
                      ),
                    ),
                    NavActions(
                      actions: [
                        IconTap(
                          path: Ic.search,
                          label: 'Search pets, services and products',
                          onPressed: () =>
                              Navigator.of(context)
                                  .push(appRoute(const SearchScreen())),
                        ),
                        IconTap(
                          path: Ic.bell,
                          label:
                              'Notifications, ${store.unreadNotifications} unread',
                          badge: store.unreadNotifications,
                          color: p.primaryFill,
                          onPressed: () =>
                              Navigator.of(context)
                                  .push(appRoute(const NotificationsScreen())),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: T.s16),
                FadeIn(index: 0, child: _NextAppointmentHero(store: store)),
                const SizedBox(height: T.s24),
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
                  _NoPetsCard(
                    onAdd: () =>
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
                SectionHeader(
                  title: 'Clinic info',
                  icon: Ic.pin,
                  actionLabel: 'Details',
                  onAction: () =>
                      Navigator.of(context)
                          .push(appRoute(const ClinicInfoScreen())),
                ),
                _ClinicCard(now: store.now),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero carousel: one page per upcoming appointment (the next five), paging
/// itself every five seconds. Zero appointments keeps the empty state; a
/// single appointment renders with no paging chrome and no timer.
class _NextAppointmentHero extends StatefulWidget {
  const _NextAppointmentHero({required this.store});
  final AppStore store;

  @override
  State<_NextAppointmentHero> createState() => _NextAppointmentHeroState();
}

class _NextAppointmentHeroState extends State<_NextAppointmentHero> {
  /// Paging beyond five turns the hero into a slideshow; the seed ships two.
  static const _maxPages = 5;

  /// Auto-advance cadence. Long enough to read the card, short enough to feel
  /// alive.
  static const _autoAdvance = Duration(seconds: 5);

  /// Idle time after the user's finger leaves before auto-advance resumes.
  static const _resumeDelay = Duration(milliseconds: 2500);

  late final PageController _pages = PageController();
  Timer? _auto;
  Timer? _resume;
  bool _holding = false;
  int _page = 0;
  int _count = -1;

  List<Appointment> get _visible =>
      widget.store.upcomingAppointments.take(_maxPages).toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reconcile();
  }

  @override
  void didUpdateWidget(covariant _NextAppointmentHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcile();
  }

  /// Keeps the controller, the dot state and the timer consistent when the
  /// appointment list changes under the carousel — a booking, a cancellation,
  /// or the clock tick dropping a finished visit.
  void _reconcile() {
    final count = _visible.length;
    if (count != _count) {
      _count = count;
      if (_page >= count) {
        _page = count <= 0 ? 0 : count - 1;
        if (_pages.hasClients) _pages.jumpToPage(_page);
      }
    }
    _syncTimer();
  }

  /// (Re)starts the auto-advance timer exactly when it should run: more than
  /// one page, motion allowed, the home route on top and tickers enabled, and
  /// no finger down. With Reduce Motion there is no timer at all — pages still
  /// change on swipe, instantly, with no animation.
  void _syncTimer() {
    _auto?.cancel();
    _auto = null;
    if (!mounted || _holding || _visible.length < 2) return;
    if (reduceMotionOf(context)) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _auto = Timer.periodic(_autoAdvance, (_) => _advance());
  }

  void _advance() {
    if (!mounted || !_pages.hasClients) return;
    final count = _visible.length;
    if (count < 2) return;
    final current = (_pages.page ?? _page.toDouble()).round() % count;
    _pages.animateToPage(
      (current + 1) % count,
      duration: Motion.base,
      curve: Motion.enter,
    );
  }

  void _pause() {
    _holding = true;
    _auto?.cancel();
    _auto = null;
    _resume?.cancel();
    _resume = null;
  }

  void _scheduleResume() {
    _holding = false;
    _resume?.cancel();
    _resume = Timer(_resumeDelay, () {
      if (mounted) _syncTimer();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _resume?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// Fixed card height, derived from the type ramp at the current text scaler:
  /// the headline always reserves two lines, so paging never moves the content
  /// below the carousel. At AX5 the slot grows with the scaler instead of
  /// clipping; a few points of slack absorb sub-pixel line-height drift.
  double _cardHeight(AppPalette p) {
    final scaler = MediaQuery.textScalerOf(context).scale(1);
    double line(TextStyle s) => s.fontSize! * (s.height ?? 1.0) * scaler;
    final row = math.max(
      42.0,
      line(Type.headline(p)) * 2 + 2 + line(Type.footnote(p)),
    );
    final chips = math.max(line(Type.caption(p)), 11.0) + 8;
    final gap = Layout.needsTallLayout(context) ? 12.0 : 10.0;
    return T.s16 * 2 + row + gap + chips + 6;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final pages = _visible;
    final imageH = Layout.heroHeight(context, 248.0);
    final cardH = _cardHeight(p);
    final pageH = imageH - 26 + cardH;

    Widget page(Appointment? a, int index) => _HeroPage(
      store: widget.store,
      a: a,
      index: index,
      count: pages.length,
      pageHeight: pageH,
      imageHeight: imageH,
      cardHeight: cardH,
      fixedCard: a != null,
    );

    if (pages.length < 2) {
      // Zero keeps the empty state; one renders with no paging chrome.
      return page(pages.isEmpty ? null : pages.single, 0);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: pageH,
          child: Listener(
            onPointerDown: (_) => _pause(),
            onPointerUp: (_) => _scheduleResume(),
            onPointerCancel: (_) => _scheduleResume(),
            child: PageView.builder(
              controller: _pages,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => page(pages[i], i),
            ),
          ),
        ),
        _Dots(count: pages.length, active: _page),
      ],
    );
  }
}

/// One carousel page: pet portrait + vet + date/time + live countdown chip,
/// with the floating frosted-glass info card in normal flow overlapping the
/// image's bottom edge.
///
/// Structural overlap, never overflow: the Column lays out in normal flow (a
/// spacer the height of the image minus the overlap, then the card) and sizes
/// the page box; the image itself is a fixed-size slot painted behind it. The
/// card is always fully inside the page box, so no ancestor can clip it —
/// unlike the old Positioned(bottom: -26) + Clip.none, which painted 26pt
/// outside the hero and depended on every ancestor not clipping.
class _HeroPage extends StatelessWidget {
  const _HeroPage({
    required this.store,
    required this.a,
    required this.index,
    required this.count,
    required this.pageHeight,
    required this.imageHeight,
    required this.cardHeight,
    required this.fixedCard,
  });

  final AppStore store;
  final Appointment? a;
  final int index;
  final int count;
  final double pageHeight;
  final double imageHeight;
  final double cardHeight;

  /// The empty state never pages, so it keeps its intrinsic card height —
  /// appointment pages share one fixed height so paging never jumps.
  final bool fixedCard;

  void _open(BuildContext context) {
    if (a == null) {
      Navigator.of(context).push(appRoute(const BookLandingScreen()));
    } else {
      Navigator.of(context)
          .push(appRoute(AppointmentDetailScreen(appointmentId: a!.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final appt = a;
    final service = appt == null ? null : store.serviceOf(appt.serviceId);
    final pet = appt == null ? null : store.pet(appt.petId);
    final staff = appt == null ? null : store.staffOf(appt.staffId);

    final label = (appt == null || pet == null)
        ? 'No upcoming appointment. Book an appointment'
        : count > 1
        ? 'Upcoming appointment ${index + 1} of $count. ${pet.name}, ${service!.name}, '
              '${mediumDate(appt.start)}, with ${staff!.name}. ${appt.status.label}'
        : 'Next appointment. ${pet.name}, ${service!.name}, '
              '${mediumDate(appt.start)}, with ${staff!.name}. ${appt.status.label}';

    final hero = Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: imageHeight,
          child: Stack(
            children: [
              // Hero imagery
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(T.rCard),
                  child: pet == null
                      ? PetArt(seed: 1, iconSize: imageHeight * 0.62)
                      : PetAvatar(
                          pet: pet,
                          iconSize: imageHeight * 0.62,
                          label: '${pet.name} portrait',
                        ),
                ),
              ),
              // Scrim so the glass card always has contrast behind it.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(T.rCard),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF000000).withValues(alpha: 0.04),
                          const Color(0xFF000000).withValues(alpha: 0.20),
                          const Color(0xFF000000).withValues(alpha: 0.34),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: T.s16,
                top: T.s16,
                child: StatusChip(
                  label: appt == null ? 'No bookings yet' : 'Next appointment',
                  icon: Ic.calendar,
                  fg: T.espresso,
                  bg: T.cream.withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
        // Floating glass card overlapping the image's bottom edge.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: imageHeight - 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GlassCard(
                border: p.isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x8CFFFFFF),
                height: fixedCard ? cardHeight : null,
                child: appt == null || pet == null
                    ? _EmptyHeroBody(pet: pet)
                    : _HeroBody(
                        store: store,
                        a: appt,
                        pet: pet,
                        service: service!,
                        staffName: staff!.name,
                        compact: Layout.needsTallLayout(context),
                      ),
              ),
            ),
          ],
        ),
      ],
    );

    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          scale: 0.99,
          onTap: () => _open(context),
          child: fixedCard ? SizedBox(height: pageHeight, child: hero) : hero,
        ),
      ),
    );
  }
}

/// Page indicators. Decorative — the position is also announced in each page's
/// semantics label — so they stay out of the accessibility tree.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              AnimatedContainer(
                duration: reduce ? Duration.zero : Motion.fast,
                curve: Motion.enter,
                width: i == active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == active
                      ? T.terracotta
                      : T.taupe.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(T.rPill),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroBody extends StatelessWidget {
  const _HeroBody({
    required this.store,
    required this.a,
    required this.pet,
    required this.service,
    required this.staffName,
    required this.compact,
  });

  final AppStore store;
  final Appointment a;
  final Pet pet;
  final Service service;
  final String staffName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    // Lives inside the carousel's fixed-height glass card, so it fills the
    // card and centers its content: one-line headlines get even breathing room
    // instead of a taller-looking card than their two-line siblings.
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pet.color.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Ic.svg(
                pet.species == Species.dog ? Ic.dog : Ic.cat,
                color: p.primaryFill,
                size: 22,
                stroke: 2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${pet.name} · ${service.name}',
                    style: Type.headline(p),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Single line, always: at AX5 this used to wrap and push
                  // the card — and the page — taller than its siblings.
                  Text(
                    '${mediumDate(a.start)} · $staffName',
                    style: Type.footnote(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Ic.svg(
              Ic.chevronRight,
              color: p.primaryFill,
              size: 18,
              stroke: 2.4,
            ),
          ],
        ),
        SizedBox(height: compact ? 12 : 10),
        // One horizontal row, never a Wrap: the chip set is fixed, so a scroll
        // row keeps the card height identical across states instead of jumping
        // when the chips reflow to two rows on narrow screens.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              StatusChip(
                label: countdownLabel(store.now, a.start),
                icon: Ic.clock,
                compact: true,
                fg: p.warning,
                bg: T.amber.withValues(alpha: 0.32),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: a.status.short,
                icon: a.status == ApptStatus.confirmed
                    ? Ic.checkCircle
                    : Ic.clock,
                compact: true,
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: peso(a.price),
                icon: Ic.wallet,
                compact: true,
                fg: p.accentText,
                bg: p.accent.withValues(alpha: 0.12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyHeroBody extends StatelessWidget {
  const _EmptyHeroBody({required this.pet});
  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nothing booked yet', style: Type.headline(p)),
              const SizedBox(height: 2),
              Text(
                'Book a visit and we will handle the reminders.',
                style: Type.footnote(p),
              ),
            ],
          ),
        ),
        StatusChip(label: 'Book', icon: Ic.arrowRight, compact: true),
      ],
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
      (
        label: 'Shop',
        icon: Ic.bag,
        onTap: () =>
            Navigator.of(context).push(appRoute(const ShopLandingScreen())),
      ),
    ];
    // Height grows with Dynamic Type so tiles never clip their labels.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final h = 92 * scale.clamp(1.0, 1.6);
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(T.rCard),
              border: Border.all(color: p.divider),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Ic.svg(icon, color: p.accent, size: 24, stroke: 1.9),
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
      height: 132,
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
                child: Container(
                  width: 168,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(T.rCard),
                    border: Border.all(color: p.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(T.rCard - 1),
                                ),
                                child: PetAvatar(
                                  pet: pet,
                                  iconSize: 54,
                                  label: '${pet.name} portrait',
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: StatusChip(
                                label: pet.species == Species.dog
                                    ? 'Dog'
                                    : 'Cat',
                                compact: true,
                                fg: T.espresso,
                                bg: T.cream.withValues(alpha: 0.86),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pet.name,
                                    style: Type.headline(p),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${pet.ageLabel} · ${pet.weightKg} kg',
                                    style: Type.caption(p),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Ic.svg(
                              Ic.chevronRight,
                              color: p.textSecondary,
                              size: 15,
                              stroke: 2.2,
                            ),
                          ],
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
    );
  }
}

/// Zero-pet empty state with a single clear next action.
class _NoPetsCard extends StatelessWidget {
  const _NoPetsCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SoftCard(
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: T.amber.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Ic.svg(Ic.paw, color: p.accent, size: 30, stroke: 1.8),
            ),
          ),
          const SizedBox(height: T.s12),
          Text(
            'Add your first pet',
            style: Type.headline(p),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Once Biscuit is here you can track visits, vaccines and documents in one place.',
            style: Type.footnote(p).copyWith(color: p.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: T.s16),
          PrimaryButton(label: 'Add pet', icon: Ic.plus, onPressed: onAdd),
        ],
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
                'Notifications are turned off for PetCare, so reminders cannot reach you. '
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
        'PetCare will remind you about medications, vaccine dates, appointments and grooming rebooks. '
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

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final open = clinicOpenAt(now);
    return SoftCard(
      onTap: () =>
          Navigator.of(context).push(appRoute(const ClinicInfoScreen())),
      semanticLabel:
          'Clinic information. ${clinicStatusLine(now)}. ${Seed.clinicAddress}',
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
                    Ic.pin,
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
                    Text(Seed.clinicName, style: Type.headline(p)),
                    const SizedBox(height: 3),
                    // Text status, never colour-only.
                    StatusChip(
                      label: open ? 'Open now' : 'Closed now',
                      icon: open ? Ic.checkCircle : Ic.clock,
                      compact: true,
                      fg: open ? p.success : p.warning,
                      bg: open
                          ? const Color(0xFFDDF2E3)
                          : T.amber.withValues(alpha: 0.28),
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
          const SizedBox(height: 12),
          Divider(height: 1, color: p.divider),
          const SizedBox(height: 10),
          _InfoLine(icon: Ic.clock, text: clinicStatusLine(now)),
          const SizedBox(height: 7),
          _InfoLine(icon: Ic.pin, text: Seed.clinicAddress),
          const SizedBox(height: 7),
          _InfoLine(icon: Ic.phone, text: Seed.clinicPhone),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
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
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Ic.svg(icon, color: p.textSecondary, size: 16),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: Type.footnote(p))),
      ],
    );
  }
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
                'PetCare AI answers instantly; the clinic team replies during clinic hours.',
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
