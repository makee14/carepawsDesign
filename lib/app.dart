import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'data/models.dart';
import 'data/seed.dart';
import 'data/clinic.dart';
import 'design/icons.dart';
import 'design/motion.dart';
import 'design/theme.dart';
import 'design/tokens.dart';
import 'screens/appointments_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/shops_screen.dart';
import 'state/app_store.dart';
import 'widgets/common.dart';

/// Splash + auth. The CarePaws logo mark appears here (and only here).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _ready = false;

  /// Looping logo animation: a slow breathing scale + a halo ring that
  /// expands and fades, forever. Reduced motion parks everything at rest.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery (used by reduceMotionOf) is only safe to read here, not in
    // initState. Guards the repeat so later dependency changes do not
    // restart the loop.
    if (!_loop.isAnimating && !reduceMotionOf(context)) _loop.repeat();
  }

  Future<void> _boot() async {
    final store = AppScope.read(context);
    await store.ai.bootstrap();
    // Portraits are rehydrated after the AI probe so a slow disk read never
    // holds up the first frame.
    unawaited(store.loadPhotos());
    if (!mounted) return;
    // Deliberately does NOT advance on its own any more. The previous version
    // pushed the app after 420ms, which made the "Get started" button
    // impossible to actually press.
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// Splash → onboarding (first launch) → sign-in. The app itself is only
  /// reachable once the credentials have been accepted.
  Future<void> _goToLogin() async {
    final done = widget.onDone;
    final navigator = Navigator.of(context);
    final store = AppScope.read(context);
    if (!store.onboardingSeen) {
      await navigator.push<void>(
        appRoute(
          OnboardingScreen(
            onDone: () {
              // Onboarding marks itself seen; continue to sign-in on the
              // same stack so Back returns to the last onboarding page
              // rather than the splash.
              navigator.push<void>(
                appRoute(
                  LoginScreen(
                    onSignedIn: () {
                      if (done != null) {
                        done();
                      } else {
                        navigator.pushReplacement(appRoute(const RootShell()));
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      return;
    }
    await navigator.push<void>(
      appRoute(
        LoginScreen(
          onSignedIn: () {
            if (done != null) {
              done();
            } else {
              navigator.pushReplacement(appRoute(const RootShell()));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: _Glow(size: 230, color: T.amber.withValues(alpha: 0.30)),
          ),
          Positioned(
            bottom: -40,
            left: -60,
            child: _Glow(size: 210, color: T.orange.withValues(alpha: 0.22)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(T.s24),
              child: Column(
                children: [
                  // Optical centering: the hero sits at the true screen
                  // centre (11:8 split of the free space compensates the
                  // bottom CTA block) instead of floating high.
                  const Spacer(flex: 11),
                  // Staggered arrival: mark, wordmark, then tagline. Each piece
                  // waits on the one before it so the screen assembles instead
                  // of appearing all at once.
                  Column(
                    children: [
                      FadeIn(
                        duration: Motion.slow,
                        child: _LoopingLogo(loop: _loop, size: 152),
                      ),
                      const SizedBox(height: T.s24),
                      FadeIn(
                        index: 1,
                        child: Text(
                          'CAREPAWS',
                          style: Type.largeTitle(p).copyWith(
                            letterSpacing: 5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeIn(
                        index: 2,
                        child: Text(
                          'Veterinary Clinic',
                          style: Type.footnote(p).copyWith(
                            fontSize: 15,
                            letterSpacing: 1.6,
                            color: p.accentText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 8),
                  FadeIn(
                    index: 4,
                    child: SizedBox(
                      width: 200,
                      child: PrimaryButton(
                        label: 'Get started',
                        icon: Ic.arrowRight,
                        onPressed: _ready ? _goToLogin : null,
                        busy: !_ready,
                      ),
                    ),
                  ),
                  const SizedBox(height: T.s12),
                  Text(Seed.appVersion, style: Type.caption(p)),
                  const SizedBox(height: T.s12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The CarePaws logo mark — the badge alone (dog + cat heads, heart in
/// negative space), rendered from [Ic.badgeArtwork]. Per the one-mark rule
/// the mark appears alone: no tile, no wordmark. It is the same badge as
/// the launcher icon's, so in-app logo and app icon stay one mark.
/// Used on splash and auth only.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 120});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'CarePaws Veterinary Clinic logo',
      child: SizedBox.square(
        dimension: size,
        child: Ic.badgeIcon(size: size),
      ),
    );
  }
}

/// Splash-only wrapper: the logo mark breathes on a loop — a slow scale
/// pulse plus a halo ring that expands and fades. Under reduced motion the
/// controller never starts and the mark renders at rest.
class _LoopingLogo extends StatelessWidget {
  const _LoopingLogo({required this.loop, required this.size});
  final Animation<double> loop;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loop.value;
        // 0..1..0 breathing scale over the cycle.
        final scale = 1.0 + 0.045 * math.sin(t * math.pi * 2);
        // Halo: expands from the badge edge and fades, twice per cycle.
        final haloT = (t * 2) % 1.0;
        return SizedBox.square(
          dimension: size * 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.35 * (1 - haloT),
                child: Container(
                  width: size * (1.02 + 0.30 * haloT),
                  height: size * (1.02 + 0.30 * haloT),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: T.orange.withValues(alpha: 0.55),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: scale,
                child: LogoMark(size: size),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Bottom tab scaffold: HOME · CHATS · APPOINTMENTS · SHOPS · PROFILE.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  static const tabs = [
    (label: 'Home', icon: Ic.home),
    (label: 'Chats', icon: Ic.chat),
    (label: 'Appointments', icon: Ic.calendar),
    (label: 'Shop', icon: Ic.bag),
    (label: 'Profile', icon: Ic.person),
  ];

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  AppStore? _store;

  /// Which tab is showing.
  int _index = 0;

  /// How deep each tab's own Navigator is. Zero means the tab's own root.
  ///
  /// The floating bar is only shown on a root route: on a pushed screen it
  /// would sit over the screen's own bottom furniture (chat composer, sticky
  /// CTA) and swallow taps.
  final _depths = List<int>.filled(RootShell.tabs.length, 0);

  /// Created once. Handing CupertinoTabView fresh observers on every build
  /// would re-register them against each Navigator.
  final _observers = <NavigatorObserver>[];

  bool get _barVisible => _depths[_index] == 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppScope.of(context);
    if (identical(store, _store)) return;
    _store?.removeListener(_onStore);
    _store = store;
    store.addListener(_onStore);
    _index = store.tab.clamp(0, 4);
  }

  void _select(int i) {
    AppScope.read(context).tab = i;
    setState(() => _index = i);
  }

  /// Keeps the bar in step with programmatic tab changes.
  void _onStore() {
    final want = _store?.tab ?? 0;
    if (want == _index) return;
    if (mounted) setState(() => _index = want.clamp(0, 4));
  }

  @override
  void dispose() {
    _store?.removeListener(_onStore);
    super.dispose();
  }

  List<NavigatorObserver> _observersFor(int i) {
    if (_observers.isEmpty) {
      for (var t = 0; t < _bodies.length; t++) {
        _observers.add(_TabDepthObserver(_onDepthChanged, _depths, t));
      }
    }
    return [_observers[i]];
  }

  /// Navigator observers fire while the Navigator is building, so the shell
  /// cannot be marked dirty straight away — that would be a setState during
  /// build. Defer to after the frame.
  void _onDepthChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _barVisible;
    // Only reserve room while the bar is actually on screen, so pushed screens
    // get their full height back and StickyCta drops back to the edge.
    final clearance = visible ? FloatingTabBar.clearanceFor(context) : 0.0;

    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      child: Stack(
        children: [
          Positioned.fill(
            // Lists reserve room for the floating bar via [TabBarClearance].
            // MediaQuery padding is left alone so SafeArea — and therefore
            // StickyCta — keeps behaving as it does on a non-floating bar.
            child: TabBarClearance(
              height: clearance,
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < _bodies.length; i++)
                    CupertinoTabView(
                      navigatorObservers: _observersFor(i),
                      builder: (_) => _bodies[i],
                    ),
                ],
              ),
            ),
          ),
          // Fades rather than sliding. The bar is a large element sitting at the
          // edge of the field of view, and HIG ▸ Motion asks that movement there
          // be avoided: travelling a whole bar-width downward communicates
          // nothing the fade does not already say. Same object leaving, no
          // second motion competing with the page push behind it.
          //
          // IgnorePointer matters as much as the fade: an AnimatedOpacity at
          // zero is still hit-testable, so an invisible bar kept swallowing
          // taps meant for the pushed screen underneath it — chat composer,
          // sticky CTAs, Done/Cancel buttons. Hidden means untouchable.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: Motion.fast,
                curve: Motion.enter,
                child: FloatingTabBar(
                  index: _index,
                  onSelect: _select,
                  tabs: RootShell.tabs,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _bodies = <Widget>[
    HomeScreen(),
    ChatsScreen(),
    AppointmentsScreen(),
    ShopsScreen(),
    ProfileScreen(),
  ];
}

/// Tracks how deep one tab's Navigator is, so the shell can hide the floating
/// bar while a detail screen is pushed.
class _TabDepthObserver extends NavigatorObserver {
  _TabDepthObserver(this._onChange, this._depths, this._tab);

  final VoidCallback _onChange;
  final List<int> _depths;
  final int _tab;

  /// The Navigator reports a push for the route it starts on. That is the tab's
  /// own root, not a detail screen, so it must not count.
  bool _sawInitialRoute = false;

  int get _depth => _depths[_tab];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_sawInitialRoute) {
      _sawInitialRoute = true;
      return;
    }
    _depths[_tab] = _depth + 1;
    _onChange();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depths[_tab] = math.max(0, _depth - 1);
    _onChange();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _depths[_tab] = math.max(0, _depth - 1);
    _onChange();
  }
}

/// Large-title sliver header with no dead row above the title.
///
/// [CupertinoSliverNavigationBar] always keeps a 44pt bar above the large title,
/// even when the title is fully expanded — and hides the small title while it is
/// expanded. On a notched phone that leaves a blank strip between the status bar
/// and the title, roughly 44pt of nothing above the fold.
///
/// This puts the large title where that strip used to be and shrinks it into the
/// 44pt bar as the page scrolls, so the header collapses exactly like the stock
/// one but never wastes a row.
class LargeTitleBar extends StatelessWidget {
  const LargeTitleBar({
    super.key,
    required this.title,
    this.automaticallyImplyLeading = false,
  });

  final String title;
  final bool automaticallyImplyLeading;

  /// Height of the collapsed bar, matching [DetailNavBar].
  static const collapsedHeight = 44.0;

  /// Extra room the large title needs beyond the collapsed bar.
  static const expandedExtra = 20.0;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _LargeTitleDelegate(
        title: title,
        background: p.background,
        divider: p.divider,
        textStyle: Type.largeTitle(p),
        topPadding: MediaQuery.paddingOf(context).top,
      ),
    );
  }
}

class _LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  _LargeTitleDelegate({
    required this.title,
    required this.background,
    required this.divider,
    required this.textStyle,
    required this.topPadding,
  });

  final String title;
  final Color background;
  final Color divider;
  final TextStyle textStyle;

  /// Passed in by the widget — a delegate has no [BuildContext] to read this.
  final double topPadding;

  static const _large = 34.0;
  static const _small = 17.0;

  @override
  double get minExtent => topPadding + LargeTitleBar.collapsedHeight;

  @override
  double get maxExtent =>
      topPadding + LargeTitleBar.collapsedHeight + LargeTitleBar.expandedExtra;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final top = topPadding;
    final delta = LargeTitleBar.expandedExtra;
    final t = delta <= 0 ? 1.0 : (shrinkOffset / delta).clamp(0.0, 1.0);

    final size = _large + (_small - _large) * t;
    // Expanded: the title sits just under the status bar. Collapsed: it is
    // centred in the 44pt bar, the way a normal nav bar title is.
    final yExpanded = top + 4;
    final yCollapsed = top + (LargeTitleBar.collapsedHeight - _small) / 2 - 3;
    final y = yExpanded + (yCollapsed - yExpanded) * t;

    return Container(
      color: background,
      child: Stack(
        children: [
          Positioned(
            left: 20,
            right: 20,
            top: y,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle.copyWith(fontSize: size, height: 1.2),
            ),
          ),
          // Hairline only once collapsed, so the expanded header stays clean.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: t,
              child: Container(height: 0.5, color: divider),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_LargeTitleDelegate old) =>
      old.title != title ||
      old.background != background ||
      old.divider != divider ||
      old.textStyle != textStyle ||
      old.topPadding != topPadding;
}

/// Shared route helper so every push feels the same — Apple-style.
///
/// A plain [CupertinoPageRoute] slides the new page in from the right. Apple
/// reserves that directional slide for drill-in navigation inside one flow
/// (Settings ▸ General ▸ About). Pushing *between* flows with a slide makes
/// the app feel like it is endlessly burrowing sideways, which is exactly
/// what the feedback called out. So this uses a custom page route with no
/// slide at all: the outgoing page holds still, the incoming page
/// cross-fades + settles with a 2% scale (like an Apple sheet / App Store
/// card), hardening to a pure fade under Reduce Motion. The iOS back-swipe
/// gesture still works via [CupertinoRouteTransitionMixin].
Route<void> appRoute(Widget page) => _FadeScaleRoute<void>(page: page);

class _FadeScaleRoute<R> extends PageRoute<R>
    with CupertinoRouteTransitionMixin<R> {
  _FadeScaleRoute({required this.page});

  final Widget page;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildContent(BuildContext context) => page;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduce = reduceMotionOf(context);
    if (reduce) {
      return FadeTransition(
        opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
        child: child,
      );
    }
    final fade = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    final scale = animation.drive(
      Tween(
        begin: 0.98,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    final outFade = ReverseAnimation(secondaryAnimation)
        .drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: outFade,
      child: FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }

  @override
  String get title => '';
}

Future<void> showAppSheet(
  BuildContext context, {
  required Widget child,
  bool scrollable = true,
}) {
  return showPopup<void>(
    context,
    builder: (_) => _AppSheet(scrollable: scrollable, child: child),
  );
}

/// Dismisses the current sheet / page if there is somewhere to go.
///
/// A bare `Navigator.pop()` is a no-op (and reads as "broken button") when
/// the sheet was opened as the *first* route — the SHOT harness boots single
/// screens directly, and deep flows can strand a Done on an empty stack. This
/// pops when possible and otherwise pops to the first route, so every
/// Done / Close / Exit / Cancel always visibly does something.
void dismissSheet(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
  } else {
    nav.popUntil((r) => r.isFirst);
  }
}

/// Completes a flow: switches to the given tab, then pops to that tab's
/// root. Done buttons use this (not bare dismiss) so the user lands in the
/// section the flow belongs to — booking → Appointments, order → Shop —
/// instead of wherever the flow happened to be opened from.
void doneToTab(BuildContext context, int tab) {
  AppScope.read(context).tab = tab;
  Navigator.of(context).popUntil((r) => r.isFirst);
}

class _AppSheet extends StatelessWidget {
  const _AppSheet({required this.child, required this.scrollable});

  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final maxH = MediaQuery.sizeOf(context).height * 0.86;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      // The background runs edge to edge; the content clears the home
      // indicator. Children bring their own top/side padding and a zero
      // bottom — this is the one place bottom safe-area is handled, so every
      // sheet clears the indicator identically.
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: p.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Always scrollable: at AX5 text sizes even a "fixed" sheet can
            // outgrow 86% of the screen — scrolling beats a render overflow.
            // The non-scrollable variant only differs in padding because its
            // children already lay out their own insets.
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(child: child)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: child,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Destructive confirmation, HIG action sheet style, label in systemRed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final result = await showPopup<bool>(
    context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title),
      message: Text(message),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(ctx).pop(false),
        child: Text(cancelLabel),
      ),
    ),
  );
  return result ?? false;
}

/// Shared date-picker sheet: the same 22pt rounded-top chrome as every other
/// sheet, Cancel/Done toolbar, safe-area aware. Returns the picked date, or
/// null on cancel / barrier tap.
Future<DateTime?> showDatePickerSheet(
  BuildContext context, {
  required DateTime initial,
  required DateTime minimum,
  required DateTime maximum,
}) async {
  var temp = initial;
  var confirmed = false;
  await showPopup<void>(
    context,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: ctx.p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => dismissSheet(ctx),
                  child: const Text('Cancel'),
                ),
                CupertinoButton(
                  onPressed: () {
                    confirmed = true;
                    dismissSheet(ctx);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: temp,
                minimumDate: minimum,
                maximumDate: maximum,
                onDateTimeChanged: (d) => temp = d,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ? temp : null;
}

/// Large-title navigation bar with an optional trailing action row.
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return CupertinoSliverNavigationBar(
      largeTitle: Text(title),
      backgroundColor: p.background.withValues(alpha: 0.88),
      border: null,
      stretch: true,
      automaticallyImplyLeading: false,
      leading: actions.isNotEmpty && actions.first is IconTap
          ? null
          : const SizedBox.shrink(),
      trailing: actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }
}

/// Common back-navigation bar for pushed screens.
class DetailNavBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const DetailNavBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack = true,
    this.previousTitle,
    this.onBack,
  });

  final String title;
  final List<Widget> actions;
  final bool showBack;
  final String? previousTitle;

  /// Overrides the back button action (e.g. step back within a multi-step
  /// flow instead of popping the route). Null keeps the default maybePop.
  final VoidCallback? onBack;

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return CupertinoNavigationBar(
      middle: Text(title, style: Type.headline(p)),
      backgroundColor: p.background.withValues(alpha: 0.9),
      border: Border(bottom: BorderSide(color: p.divider, width: 0.5)),
      automaticallyImplyLeading: false,
      leading: showBack
          ? Semantics(
              button: true,
              label: 'Back',
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 44),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Ic.svg(
                      Ic.chevronLeft,
                      color: p.accentText,
                      size: 20,
                      stroke: 2.4,
                    ),
                    if (MediaQuery.sizeOf(context).width > 400) ...[
                      const SizedBox(width: 2),
                      Text(
                        previousTitle ?? 'Back',
                        style: Type.body(p).copyWith(color: p.accentText),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : null,
      trailing: actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }
}

/// Time-aware greeting: Good morning / afternoon / evening.
String greetingFor(DateTime t) {
  final h = t.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String greetingSub(DateTime t) => switch (t.hour) {
  < 12 => 'Starting with Biscuit’s walk, then his 10 AM check-up.',
  < 17 => 'Biscuit’s visit is coming up. Here is today at CarePaws.',
  _ => 'Mochi is fed and settled. Here is tomorrow at CarePaws.',
};

/// Live countdown to the next appointment, e.g. "in 2d 6h" / "in 3h 12m".
String countdownLabel(DateTime from, DateTime to) {
  final d = to.difference(from);
  if (d.isNegative) return 'in progress';
  if (d.inDays >= 1) {
    final h = d.inHours % 24;
    return h == 0 ? 'in ${d.inDays}d' : 'in ${d.inDays}d ${h}h';
  }
  if (d.inHours >= 1) return 'in ${d.inHours}h ${d.inMinutes % 60}m';
  return 'in ${d.inMinutes}m';
}

String clockLabel(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

const monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String shortDate(DateTime d) =>
    '${dayNames[d.weekday - 1]}, ${d.day} ${monthNames[d.month - 1]}';
String mediumDate(DateTime d) =>
    '${dayNames[d.weekday - 1]}, ${d.day} ${monthNames[d.month - 1]} · ${clockLabel(d)}';
String dayMonth(DateTime d) => '${d.day} ${monthNames[d.month - 1]}';
String isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool isToday(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Clinic open/closed state, shared by Home and the emergency triage screen.
/// Hours come from [Clinic]: Mon–Sat 9:00 AM – 6:00 PM, closed Sundays.
bool clinicOpenAt(DateTime t) => Clinic.isOpenNow(t);

String clinicStatusLine(DateTime t) {
  if (Clinic.isOpenNow(t)) return 'Open now · until 6:00 PM today';
  final o = Clinic.nextOpening(t);
  final today = DateTime(t.year, t.month, t.day);
  final sameDay =
      o.year == today.year && o.month == today.month && o.day == today.day;
  final label = sameDay
      ? 'at 9:00 AM today'
      : 'at 9:00 AM ${Clinic.weekdayName(o.weekday)}';
  return 'Closed now · opens $label';
}

/// Shared pet picker row.
class PetChip extends StatelessWidget {
  const PetChip({
    super.key,
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  final Pet pet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      selected: selected,
      label: '${pet.name}, ${pet.breed}',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          scale: 0.96,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: T.pressMs),
            width: 132,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? T.amber.withValues(alpha: 0.20) : p.surface,
              borderRadius: BorderRadius.circular(T.rCard),
              border: Border.all(
                color: selected ? p.accent : p.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    PetArt(
                      seed: pet.id.hashCode.abs() % 4,
                      species: pet.species,
                      radius: 12,
                      iconSize: 34,
                      label: '${pet.name} portrait',
                    ),
                    const Spacer(),
                    if (selected)
                      Ic.svg(
                        Ic.checkCircle,
                        color: p.accent,
                        size: 20,
                        stroke: 2.1,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pet.name,
                  style: Type.headline(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  pet.breed,
                  style: Type.caption(p),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
