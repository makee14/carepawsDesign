import 'package:flutter/cupertino.dart';

import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../widgets/common.dart';
import 'onboarding_illustrations.dart';

/// Apple-style onboarding: full-screen cards you swipe through.
/// 5 pages: Welcome, Pets, AI Health Check, Booking, Shop + chat.
/// Shown once (splash -> onboarding -> login), replayable from Help.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _titles = [
    'All your pets,\none calm place',
    'Not sure if it\ncan wait?',
    'Booking that\nrespects your day',
    'A real team\nbehind the chat',
    'Food, meds &\ngrooming to go',
  ];
  static const _bodies = [
    'Biscuit, Mochi and every visit, vaccine and document — together in one app, so the clinic always sees the full picture.',
    'Run a 30-second AI health check any time. Tell us what you see, add a photo if you like, and we point you to home care, a chat, a booking — or straight to the phone when it is urgent.',
    'Pick a pet, a service and a time. Routine visits confirm instantly; if your pet seems unwell the vet reviews the health check first.',
    'CarePaws AI answers instantly, day or night. The clinic team replies during hours, usually within 10 minutes.',
    'Order from the clinic shop and collect at the counter with a pickup code. Prescription items unlock once the vet signs.',
  ];
  static const _illustrations = [
    PawIntro(),
    AiOrbIntro(),
    BookIntro(),
    ChatIntro(),
    ShopIntro(),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    // Finishing (or skipping) the tour does NOT complete the first-launch
    // flow — registration is still pending. The completed flag is written
    // only once the user reaches Home.
    widget.onDone();
  }

  void _next() {
    if (_page >= _titles.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(duration: Motion.base, curve: Motion.enter);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final last = _page == _titles.length - 1;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(64, 44),
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: Type.body(p).copyWith(color: p.accentText),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      for (var i = 0; i < _titles.length; i++)
                        AnimatedContainer(
                          // Expanding pill for the active dot; static under
                          // reduced motion.
                          duration: reduceMotionOf(context)
                              ? Duration.zero
                              : Motion.fast,
                          margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page ? p.accent : p.divider,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _titles.length,
                itemBuilder: (context, i) => _Page(
                  active: i == _page,
                  illustration: _illustrations[i],
                  title: _titles[i],
                  body: _bodies[i],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                20 + MediaQuery.paddingOf(context).bottom * 0.3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: last ? 'Get started' : 'Continue',
                    icon: last ? Ic.check : Ic.arrowRight,
                    onPressed: _next,
                  ),
                  if (!last) ...[
                    const SizedBox(height: 8),
                    SecondaryButton(label: 'Skip tour', onPressed: _finish),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One onboarding page: fixed-size animated illustration slot, then the
/// staggered title/body entrance.
///
/// The illustration slot never changes size with text scale — the drawing is
/// authored on a fixed canvas and fitted into the slot, so AX5 text can't push
/// it into an overflow. The page itself scrolls when the copy outgrows the
/// viewport (AX5, landscape).
///
/// When the page becomes the current one ([active] flips false→true) the
/// entrance replays: the illustration subtree is re-keyed so its one-shot
/// timeline restarts, and the title/body [FadeIn]s are re-keyed too.
class _Page extends StatefulWidget {
  const _Page({
    required this.active,
    required this.illustration,
    required this.title,
    required this.body,
  });

  final bool active;
  final Widget illustration;
  final String title;
  final String body;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  int _run = 0;

  @override
  void didUpdateWidget(covariant _Page oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      setState(() => _run++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    // Compressed slot in landscape so the copy and CTA stay on screen.
    final wide =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final slotH = wide ? 148.0 : 208.0;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            // The illustration rides high: the old centred group left the
            // artwork sitting low, crowded against the title.
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  height: slotH,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: introCanvas.width,
                      height: introCanvas.height,
                      child: IgnorePointer(
                        // Decorative: the title/body carry the meaning.
                        child: KeyedSubtree(
                          key: ValueKey('illustration$_run'),
                          child: widget.illustration,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: T.s24),
                FadeIn(
                  key: ValueKey('title$_run'),
                  child: Text(
                    widget.title,
                    style: Type.title1(p).copyWith(fontSize: 30, height: 1.15),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                FadeIn(
                  key: ValueKey('body$_run'),
                  index: 1,
                  child: Text(
                    widget.body,
                    style: Type.body(p).copyWith(color: p.textSecondary),
                    textAlign: TextAlign.center,
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
