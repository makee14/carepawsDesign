import 'package:flutter/cupertino.dart';

import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

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
    'PetCare AI answers instantly, day or night. The clinic team replies during hours, usually within 10 minutes.',
    'Order from the clinic shop and collect at the counter with a pickup code. Prescription items unlock once the vet signs.',
  ];
  static const _icons = [Ic.paw, Ic.sparkle, Ic.calendar, Ic.chat, Ic.bag];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    AppScope.read(context).completeOnboarding();
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
                    child: Text('Skip',
                        style: Type.body(p).copyWith(color: p.accentText)),
                  ),
                  const Spacer(),
                  Row(children: [
                    for (var i = 0; i < _titles.length; i++)
                      AnimatedContainer(
                        duration: Motion.fast,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                        width: i == _page ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _page ? p.accent : p.divider,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _titles.length,
                itemBuilder: (context, i) => _Page(
                  icon: _icons[i],
                  title: _titles[i],
                  body: _bodies[i],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20,
                  20 + MediaQuery.paddingOf(context).bottom * 0.3),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                PrimaryButton(
                  label: last ? 'Get started' : 'Continue',
                  icon: last ? Ic.check : Ic.arrowRight,
                  onPressed: _next,
                ),
                if (!last) ...[
                  const SizedBox(height: 8),
                  SecondaryButton(label: 'Skip tour', onPressed: _finish),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.icon, required this.title, required this.body});
  final String icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        FadeIn(
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: T.amber.withValues(alpha: p.isDark ? 0.18 : 0.24),
              shape: BoxShape.circle,
            ),
            child: Center(
                child: Ic.svg(icon, color: p.accent, size: 52, stroke: 1.6)),
          ),
        ),
        const SizedBox(height: T.s32),
        FadeIn(
          index: 1,
          child: Text(title,
              style: Type.title1(p).copyWith(fontSize: 30, height: 1.15),
              textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        FadeIn(
          index: 2,
          child: Text(body,
              style: Type.body(p).copyWith(color: p.textSecondary),
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}

