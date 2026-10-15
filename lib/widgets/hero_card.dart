import 'package:flutter/cupertino.dart';

import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// The ONE shared G1 card layout (Stream A owns it; every stream consumes it).
///
/// Vertical card: [image] fills the top ~75% edge-to-edge, the info panel
/// fills the bottom ~25% and is pulled up over the image by [panelOverlap]
/// for the layered look. A single outer [ClipRRect] (radius [T.rCard]) gives
/// the seamless rounded-rectangle read — the panel's own top corners are
/// square; the clip does the rounding.
///
/// Content varies via props/slots ([title], [description], [details]); the
/// layout shell is fixed. Break from this layout only deliberately, logged in
/// the Deviation Log — never a quiet hardcoded copy.
///
/// Geometry: the card's minimum height comes from [aspectRatio]; the image
/// takes 75% of that minimum plus [panelOverlap], and the panel flows at its
/// natural height — at AX5 the panel grows and the card grows with it instead
/// of clipping.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.image,
    required this.title,
    this.description,
    this.details = const [],
    this.onTap,
    this.aspectRatio = 4 / 3,
    this.panelOverlap = 12.0,
  });

  /// Fills the top ~75% edge-to-edge (e.g. a pet photo or [PetArt]).
  final Widget image;

  /// Panel title: 1 line, ellipsis.
  final String title;

  /// Panel description: max 2 lines, ellipsis.
  final String? description;

  /// Key-detail rows under the description, 4pt apart.
  final List<Widget> details;

  /// G2: tap reveals the full details (sheet or screen, per consumer).
  final VoidCallback? onTap;

  /// Width : minimum-height ratio. 4/3 default; Home's Next Appointment card
  /// uses 16/10 so it reads subordinate to the promo carousel.
  final double aspectRatio;

  /// How far the panel pulls up over the image — the layered look.
  final double panelOverlap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final panel = Container(
      color: p.surface,
      padding: const EdgeInsets.all(T.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Type.title3(p),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (description != null) ...[
            const SizedBox(height: T.s4),
            Text(
              description!,
              style: Type.footnote(p).copyWith(color: p.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: T.s8),
            for (var i = 0; i < details.length; i++) ...[
              if (i > 0) const SizedBox(height: T.s4),
              details[i],
            ],
          ],
        ],
      ),
    );

    final label = description == null ? title : '$title. $description';

    // Shadow lives outside the clip (a shadow inside ClipRRect would be
    // clipped away); same elevation language as SoftCard/GlassCard.
    final card = Container(
      decoration: BoxDecoration(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rCard),
        child: LayoutBuilder(
          builder: (context, c) {
            final minH = c.maxWidth / aspectRatio;
            final imageH = minH * 0.75 + panelOverlap;
            return Stack(
              children: [
                // Size driver: image space plus the panel, minus the overlap
                // the panel steals from the image.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: imageH - panelOverlap),
                    panel,
                  ],
                ),
                // The image paints over the top of the size driver; its
                // bottom `panelOverlap` is covered by the solid panel.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: imageH,
                  child: image,
                ),
              ],
            );
          },
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: _PressOpacity(onTap: onTap, child: card),
      ),
    );
  }
}

/// Press feedback for [HeroCard]: opacity 0.96 over [T.pressMs], no
/// scale-jump (per the visual contract); instant under reduced motion.
///
/// Keyboard support mirrors PressScale (the app's a11y choke point): focusable,
/// activates on Enter/Space, paints the 2pt terracotta focus ring.
class _PressOpacity extends StatefulWidget {
  const _PressOpacity({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressOpacity> createState() => _PressOpacityState();
}

class _PressOpacityState extends State<_PressOpacity> {
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    final interactive = widget.onTap != null;

    Widget content = AnimatedOpacity(
      opacity: _down && interactive ? 0.96 : 1.0,
      duration: reduce
          ? Duration.zero
          : const Duration(milliseconds: T.pressMs),
      child: widget.child,
    );

    if (_focused && interactive) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: T.terracottaDeep, width: 2),
                  borderRadius: BorderRadius.circular(T.rCard),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!interactive) return content;

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      // No explicit map type args: the theme's `Type` class shadows
      // dart:core's `Type` in this file, so inference uses the parameter's
      // own key type instead.
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}
