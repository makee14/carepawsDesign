import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../data/models.dart';
import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import 'common.dart';

/// Data-driven promo/announcement carousel (Home). Bundled seed data only —
/// there is no ad backend (orchestrator ruling).
///
/// [onCta] resolves `promo.route` to a destination; the Home screen owns that
/// map, so the carousel itself stays navigation-agnostic.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({
    super.key,
    required this.promos,
    this.autoAdvance = true,
    this.onCta,
  });

  final List<Promo> promos;
  final bool autoAdvance;
  final ValueChanged<Promo>? onCta;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  /// Long enough to read, short enough to feel alive.
  static const _period = Duration(seconds: 5);

  /// Idle time after the finger leaves before auto-advance resumes.
  static const _resumeDelay = Duration(milliseconds: 2500);

  late final PageController _pages = PageController(viewportFraction: 0.88);
  Timer? _auto;
  Timer? _resume;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  /// Runs exactly when it should: more than one page, auto-advance allowed,
  /// motion allowed, the home route on top and tickers enabled. With Reduce
  /// Motion there is no timer at all — pages still change on swipe.
  void _syncTimer() {
    _auto?.cancel();
    _auto = null;
    if (!mounted || widget.promos.length < 2) return;
    if (!widget.autoAdvance || reduceMotionOf(context)) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _auto = Timer.periodic(_period, (_) => _advance());
  }

  void _advance() {
    if (!mounted || !_pages.hasClients) return;
    final count = widget.promos.length;
    if (count < 2) return;
    final current = (_pages.page ?? _page.toDouble()).round() % count;
    _pages.animateToPage(
      (current + 1) % count,
      duration: Motion.base,
      curve: Motion.enter,
    );
  }

  @override
  void dispose() {
    // pumpAndSettle only waits for scheduled frames, not fake-async timers;
    // teardown asserts zero pending timers, so every timer dies here.
    _auto?.cancel();
    _resume?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promos = widget.promos;
    if (promos.isEmpty) return const SizedBox.shrink();
    final reduce = reduceMotionOf(context);
    // AX5: the card grows with Dynamic Type instead of clipping — 140pt
    // cannot fit 3.2x title/subtitle/CTA text.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final cardH = 140.0 * scale.clamp(1.0, 1.8);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: cardH,
          child: Listener(
            onPointerDown: (_) {
              _auto?.cancel();
              _auto = null;
              _resume?.cancel();
              _resume = null;
            },
            onPointerUp: (_) {
              _resume?.cancel();
              _resume = Timer(_resumeDelay, () {
                if (mounted) _syncTimer();
              });
            },
            onPointerCancel: (_) {
              _resume?.cancel();
              _resume = Timer(_resumeDelay, () {
                if (mounted) _syncTimer();
              });
            },
            child: PageView.builder(
              controller: _pages,
              itemCount: promos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _PromoCard(promo: promos[i], onCta: widget.onCta),
              ),
            ),
          ),
        ),
        _Dots(count: promos.length, active: _page, reduce: reduce),
      ],
    );
  }
}

/// One promo page: full-bleed generated art, bottom scrim, title + subtitle
/// bottom-left and the CTA pill bottom-right.
class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo, this.onCta});

  final Promo promo;
  final ValueChanged<Promo>? onCta;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return ClipRRect(
      borderRadius: BorderRadius.circular(T.rCard),
      child: Stack(
        children: [
          Positioned.fill(
            child: PetArt(seed: promo.art, radius: 0, iconSize: 64),
          ),
          // Bottom scrim: white text over light pastel art needs the same
          // honest contrast guarantee as the pet mini-cards (0.65 black).
          // Full-card gradient (transparent at top) so it still covers the
          // text block when the card grows at large Dynamic Type.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF000000).withValues(alpha: 0),
                    const Color(0xFF000000).withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: LayoutBuilder(
              builder: (context, c) {
                // The pill's intrinsic width at large Dynamic Type would push
                // the Row past the card edge — cap it so the text column
                // always keeps the majority of the width.
                final maxPillW = c.maxWidth * 0.42;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            promo.title,
                            style: Type.title3(p)
                                .copyWith(color: CupertinoColors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            promo.subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xE6FFFFFF),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxPillW),
                      child: _CtaPill(
                        label: promo.ctaLabel,
                        onTap: onCta == null ? null : () => onCta!(promo),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// CTA pill: 36pt visual, extended to a 44pt tap target via padding.
/// Terracotta-deep bg carries white text at 5.84:1 (see tokens).
class _CtaPill extends StatelessWidget {
  const _CtaPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          scale: 0.96,
          onTap: onTap,
          // 44pt target: 4pt vertical padding around the 36pt pill.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.terracottaDeep,
                borderRadius: BorderRadius.circular(T.rPill),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Page indicators. Decorative — position is announced by the page semantics —
/// so they stay out of the accessibility tree.
class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.active,
    required this.reduce,
  });

  final int count;
  final int active;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
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
                      ? T.orange
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
