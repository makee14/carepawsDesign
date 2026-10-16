import 'package:flutter/cupertino.dart';

import '../../data/models.dart';
import '../../design/icons.dart';
import '../../design/motion.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';

/// Badge colors for [Urgency]. Every pair is script-verified at >= 4.5:1
/// (see test/health_check_test.dart 'urgency badge contrast'):
/// - low #2E7D32 / white = 5.13:1
/// - moderate #8A5200 / white = 6.38:1 (the spec's #B26A00 measured 4.24:1
///   with white and 3.96:1 with dark text — both under 4.5 — so it was
///   darkened; see the design-contracts spec gap #3)
/// - high T.terracottaDeep / white = 5.83:1
/// - urgent T.destructive / white = 5.63:1
({Color bg, Color fg}) urgencyBadgeColors(Urgency urgency) => switch (urgency) {
  Urgency.low => (bg: const Color(0xFF2E7D32), fg: const Color(0xFFFFFFFF)),
  Urgency.moderate => (
    bg: const Color(0xFF8A5200),
    fg: const Color(0xFFFFFFFF),
  ),
  Urgency.high => (bg: T.terracottaDeep, fg: const Color(0xFFFFFFFF)),
  Urgency.urgent => (bg: T.destructive, fg: const Color(0xFFFFFFFF)),
};

String urgencyBadgeLabel(Urgency urgency) => switch (urgency) {
  Urgency.low => 'Low urgency',
  Urgency.moderate => 'Needs a visit',
  Urgency.high => 'Needs care soon',
  Urgency.urgent => 'Urgent — see a vet now',
};

/// Pill badge leading every health-check result.
class UrgencyBadge extends StatelessWidget {
  const UrgencyBadge({super.key, required this.urgency});
  final Urgency urgency;

  @override
  Widget build(BuildContext context) {
    final c = urgencyBadgeColors(urgency);
    return Semantics(
      label: 'Urgency: ${urgencyBadgeLabel(urgency)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(T.rPill),
        ),
        child: Text(
          urgencyBadgeLabel(urgency),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: c.fg,
          ),
        ),
      ),
    );
  }
}

/// Summary-first health-check result (G2: details behind expandable
/// sections). Shared by the results screen and [HealthCheckResultSheet] —
/// one layout, no forks.
///
/// [petName] is the step-0-selected pet's name, threaded in by the caller —
/// never re-derived (the old ambiguous-pet fallback produced the
/// wrong-pet-name bug).
class HealthCheckResultView extends StatelessWidget {
  const HealthCheckResultView({
    super.key,
    required this.result,
    required this.petName,
    this.leading,
    this.action,
    this.contactVet,
  });

  final HealthCheckResult result;
  final String petName;
  final Widget? leading;
  final Widget? action;
  final Widget? contactVet;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(height: T.s16)],
        UrgencyBadge(urgency: result.urgency),
        const SizedBox(height: T.s8),
        Text(result.summary, style: Type.title2(p)),
        const SizedBox(height: 4),
        Text(
          'Health check — $petName',
          style: Type.footnote(p).copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: T.s16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(T.s16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(color: p.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What to do next', style: Type.headline(p)),
              const SizedBox(height: T.s8),
              Text(result.recommendation, style: Type.callout(p)),
              if (action != null) ...[const SizedBox(height: T.s12), action!],
            ],
          ),
        ),
        if (contactVet != null) ...[const SizedBox(height: T.s12), contactVet!],
        const SizedBox(height: T.s8),
        for (final section in result.sections) _SectionTile(section: section),
        const SizedBox(height: T.s16),
        const _NotADiagnosis(),
      ],
    );
  }
}

class _SectionTile extends StatefulWidget {
  const _SectionTile({required this.section});
  final HealthSection section;

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final reduce = reduceMotionOf(context);
    // The expandable body, shared by the animated and reduced-motion paths.
    // Under reduced motion the AnimatedSize is skipped entirely — a
    // zero-duration AnimatedSize completes its controller inside
    // performLayout and throws ("mutated in its own performLayout").
    final body = _open
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, T.s16),
            child: Text(
              widget.section.body,
              style: Type.callout(p).copyWith(color: p.textSecondary),
            ),
          )
        : const SizedBox(width: double.infinity, height: 0);
    return Container(
      margin: const EdgeInsets.only(top: T.s8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(T.rControl),
        border: Border.all(color: p.divider),
      ),
      child: Column(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: T.s16),
            minimumSize: const Size(0, 56),
            onPressed: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.section.title, style: Type.headline(p)),
                ),
                // No chevronUp asset — rotate the down chevron when open.
                Transform.rotate(
                  angle: _open ? 3.1415926535 : 0,
                  child: Ic.svg(
                    Ic.chevronDown,
                    color: p.textSecondary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          ClipRect(
            child: reduce
                ? body
                : AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: body,
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotADiagnosis extends StatelessWidget {
  const _NotADiagnosis();

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ic.svg(Ic.shield, color: p.textSecondary, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'This is guidance, not a diagnosis. Only a veterinarian who examines '
              'your pet can confirm what is going on.',
              style: Type.footnote(p),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing a persisted health-check result. Stream B's
/// clinic-chat button consumes this exact API — do not change the signature
/// without coordinating with Stream B.
class HealthCheckResultSheet {
  const HealthCheckResultSheet._();

  static Future<void> show(BuildContext context, HealthCheckResult result) {
    final store = AppScope.read(context);
    final petName = store.pet(result.petId)?.name ?? 'your pet';
    return showPopup<void>(
      context,
      builder: (ctx) {
        final p = ctx.p;
        return Container(
          decoration: BoxDecoration(
            color: p.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(T.rCard),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      20 + MediaQuery.paddingOf(ctx).bottom,
                    ),
                    child: HealthCheckResultView(
                      result: result,
                      petName: petName,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SecondaryButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
