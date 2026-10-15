import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';

/// Shows a popup — a bottom sheet or a centered alert — that honors reduced
/// motion.
///
/// The Cupertino popup/dialog routes always animate; when the user asked for
/// stillness ([reduceMotionOf]) the popup appears instantly instead, via a
/// zero-duration [showGeneralDialog]. Everything else — barrier behaviour,
/// placement, dismissal — matches the animated path, so this is a drop-in
/// replacement for [showCupertinoModalPopup] (bottom sheets) and
/// [showCupertinoDialog] (centered alerts, pass `centered: true` and
/// `barrierDismissible: false`).
///
/// Popups open on the *nearest* navigator ([useRootNavigator] false), not the
/// root one: [dismissSheet] pops `Navigator.of(context)`, so a sheet parked
/// on the root navigator would leave its Done button popping the page *under*
/// the sheet instead of the sheet itself.
Future<R?> showPopup<R>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool centered = false,
  bool barrierDismissible = true,
}) {
  if (reduceMotionOf(context)) {
    return showGeneralDialog<R>(
      context: context,
      barrierColor: const Color(0x66000000),
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      transitionDuration: Duration.zero,
      useRootNavigator: false,
      pageBuilder: (ctx, _, _) => Align(
        alignment: centered ? Alignment.center : Alignment.bottomCenter,
        child: builder(ctx),
      ),
    );
  }
  if (centered) {
    return showCupertinoDialog<R>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: false,
      builder: builder,
    );
  }
  return showCupertinoModalPopup<R>(
    context: context,
    barrierColor: const Color(0x66000000),
    barrierDismissible: barrierDismissible,
    useRootNavigator: false,
    builder: builder,
  );
}

/// Dials [number] via tel:. On devices with no dialer (desktop, simulators),
/// shows the number in a sheet instead of a dead end.
Future<void> callPhoneNumber(
  BuildContext context, {
  required String number,
  required String name,
}) async {
  final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
  var ok = false;
  try {
    ok =
        await launchUrl(uri) ||
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!context.mounted) return;
  if (!ok) {
    await showPopup<void>(
      context,
      centered: true,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(name),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('$number\n\nDial this number from your phone.'),
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

/// Frosted-glass surface: backdrop blur, 1px translucent border, layered depth.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(T.s16),
    this.radius = T.rCard,
    this.tint,
    this.border,
    this.blur = T.glassBlur,
    this.onTap,
    this.semanticLabel,
    this.width,
    this.height,
    this.clipContent = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tint;
  final Color? border;
  final double blur;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double? width;
  final double? height;
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final body = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: tint ?? p.glassTint,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? p.glassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: p.isDark ? p.glassShadow : T.shadowLight,
            blurRadius: T.shadowBlur,
            offset: const Offset(0, T.shadowDy),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (onTap == null) return body;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: PressScale(onTap: onTap, child: body),
      ),
    );
  }
}

/// Floating pill tab bar.
///
/// One capsule that floats above the content rather than owning a strip of the
/// layout, so page content scrolls behind it — the shell adds matching bottom
/// padding so the last row is still reachable.
///
/// Sizing and placement come from the design spec:
///   * 64pt tall, fully rounded (radius = height / 2)
///   * 16pt margins left and right, centred horizontally
///   * floats [lift] above the bottom safe area, never over the home indicator
///   * five evenly spaced slots, each icon over a label
///   * every slot is at least 44x44pt
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.tabs,
  });

  /// Current tab index.
  final int index;
  final ValueChanged<int> onSelect;

  final List<({String label, String icon})> tabs;

  static const height = 64.0;
  static const sideMargin = 16.0;
  static const lift = 10.0;
  static const blur = 10.0;

  /// Height the shell reserves so scrolling content clears the bar.
  static double clearanceFor(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return height + lift + bottom + 12;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Notch insets apply sideways in landscape, so they widen the margins.
    final horizontal = media.padding.left + media.padding.right;

    // Padding rather than Positioned: the shell places this inside its own
    // AnimatedOpacity, and a nested Positioned would be a ParentData mismatch.
    return Padding(
      padding: EdgeInsets.only(
        left: sideMargin + horizontal,
        right: sideMargin + horizontal,
        // Clears the home indicator; `lift` is the gap above it.
        bottom: media.padding.bottom + lift,
      ),
      child: RepaintBoundary(
        // GlassCard rather than a bare BackdropFilter: the filter has to sit
        // inside a ClipRRect or it samples everything painted beneath it in the
        // Stack and blurs the whole page, not just the pill.
        child: GlassCard(
          radius: height / 2,
          padding: EdgeInsets.zero,
          blur: blur,
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                _Slot(
                  label: tabs[i].label,
                  icon: tabs[i].icon,
                  selected: index == i,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final fg = selected ? p.primaryFill : (p.isDark ? T.sand : T.taupe);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: ExcludeSemantics(
          child: PressScale(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: SizedBox(
              height: FloatingTabBar.height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Ic.svg(
                    icon,
                    color: fg,
                    size: 21,
                    stroke: selected ? 2.2 : 1.9,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Tab labels are fixed chrome in a 64pt slot: cap the
                    // scale so AX5 (3.2) still fits instead of overflowing
                    // the slot by 4px. 1× rendering is untouched.
                    textScaler: MediaQuery.textScalerOf(context)
                        .clamp(maxScaleFactor: 2.5),
                    style: Type.caption(p).copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical room a scrolling screen must leave at the bottom so its last row
/// clears the floating [FloatingTabBar].
///
/// This is deliberately *not* injected into `MediaQuery.padding`: padding is
/// read by `SafeArea`, and inflating it would also push up every `StickyCta`
/// and shrink the scroll area above it. Only list paddings should consume this.
class TabBarClearance extends InheritedWidget {
  const TabBarClearance({
    super.key,
    required this.height,
    required super.child,
  });

  final double height;

  static double of(BuildContext context) {
    final m = context.dependOnInheritedWidgetOfExactType<TabBarClearance>();
    return m?.height ?? 0;
  }

  @override
  bool updateShouldNotify(TabBarClearance oldWidget) =>
      oldWidget.height != height;
}

/// Floating pill tab bar.
///
/// [CupertinoTabScaffold] insists on a real [CupertinoTabBar], so rather than
/// hand-rolling a tab shell this subclasses the stock bar and wraps it in a
/// detached frosted pill: inset from both edges, curved corners, hairline
/// border, drop shadow.
///
/// The caller passes a transparent `backgroundColor` and an empty `border` so
/// only the glass surface shows — the stock bar's own fill and top rule are
/// what make it read as a flat strip.
class GlassTabBar extends CupertinoTabBar {
  const GlassTabBar({
    super.key,
    required super.items,
    required super.onTap,
    super.activeColor,
    super.inactiveColor,
    super.backgroundColor,
    super.border,
    super.iconSize,
    super.height,
  });

  /// Inset from each side. Narrow enough to read as floating, wide enough that
  /// five labelled tabs stay comfortable to hit.
  static const sideInset = 14.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(sideInset, 0, sideInset, 6),
      child: GlassCard(
        radius: 26,
        padding: EdgeInsets.zero,
        child: super.build(context),
      ),
    );
  }
}

/// Opaque white card on cream — used where blur would hurt legibility.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(T.s16),
    this.radius = T.rCard,
    this.color,
    this.onTap,
    this.semanticLabel,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
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
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: PressScale(onTap: onTap, child: card),
      ),
    );
  }
}

/// Terracotta-switch row used by the reminders surfaces.
class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final String iconPath;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      toggled: value,
      label: '$title. $subtitle',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: T.tap),
          padding: const EdgeInsets.fromLTRB(T.s16, 10, 10, 10),
          child: Row(
            children: [
              Ic.svg(iconPath, color: p.accent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: Type.headline(p)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Type.footnote(p)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoSwitch(
                value: value,
                activeTrackColor: p.accent,
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grouped list row, HIG style. min 56pt, chevron when navigable.
class RowTile extends StatelessWidget {
  const RowTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingPath,
    this.leadingColor,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.destructive = false,
    this.iconBg,
  });

  final String title;
  final String? subtitle;
  final String? leadingPath;
  final Color? leadingColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool destructive;
  final Color? iconBg;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final t = destructive ? p.destructive : p.text;
    return Semantics(
      button: onTap != null,
      label: [title, ?subtitle].join('. '),
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          scale: 0.985,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: T.s16,
              vertical: 11,
            ),
            child: Row(
              children: [
                if (leadingPath != null) ...[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconBg ?? p.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Ic.svg(
                      leadingPath!,
                      color:
                          leadingColor ??
                          (destructive ? p.destructive : p.accent),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: Type.body(p).copyWith(color: t)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: Type.footnote(p)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                if (onTap != null && showChevron) ...[
                  const SizedBox(width: 4),
                  Ic.svg(
                    Ic.chevronRight,
                    color: p.textSecondary,
                    size: 16,
                    stroke: 2.2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Text-labelled chip. Never colour-only: always carries a word or icon+word.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.fg,
    this.bg,
    this.compact = false,
    this.bold = true,
  });

  final String label;
  final String? icon;
  final Color? fg;
  final Color? bg;
  final bool compact;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg ?? p.chipBg,
        borderRadius: BorderRadius.circular(T.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Ic.svg(
              icon!,
              color: fg ?? p.chipText,
              size: compact ? 11 : 13,
              stroke: 2.2,
            ),
            SizedBox(width: compact ? 3 : 5),
          ],
          Flexible(
            child: Text(
              label,
              style: (compact ? Type.caption(p) : Type.footnote(p)).copyWith(
                color: fg ?? p.chipText,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small frosted-glass pill for labels floating over photos (pet species on
/// the pet cards). Cream text over a white 14% tint stays readable on light
/// and dark photos alike; glass is used here because it floats over imagery.
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return ClipRRect(
      borderRadius: BorderRadius.circular(T.rPill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            // Dark glass: the pill floats over pet photos, so the tint has
            // to carry the contrast itself — script-verified 5.23:1 for the
            // cream label over the worst case (a white photo).
            color: const Color(0xFF000000).withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: Type.caption(p)
                .copyWith(color: T.cream, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Selectable filter chip.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          scale: 0.95,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: T.pressMs),
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? p.primaryFill : p.surface,
              borderRadius: BorderRadius.circular(T.rPill),
              border: Border.all(color: selected ? p.primaryFill : p.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Ic.svg(
                    icon!,
                    color: selected ? p.onPrimaryFill : p.textSecondary,
                    size: 14,
                    stroke: 2.1,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Type.footnote(p).copyWith(
                    color: selected ? p.onPrimaryFill : p.text,
                    fontWeight: FontWeight.w600,
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

/// Section header with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(0, T.s24, 0, T.s12),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Ic.svg(icon!, color: p.accent, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(title, style: Type.title2(p))),
          if (actionLabel != null)
            Semantics(
              button: true,
              label: actionLabel,
              child: ExcludeSemantics(
                child: PressScale(
                  onTap: onAction,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 44,
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel!,
                          style: Type.footnoteEmph(p)
                              .copyWith(color: p.accentText),
                        ),
                        const SizedBox(width: 3),
                        Ic.svg(
                          Ic.chevronRight,
                          color: p.accentText,
                          size: 14,
                          stroke: 2.2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal icon + value + label strip.
class StatStrip extends StatelessWidget {
  const StatStrip({
    super.key,
    required this.stats,
    this.padding = const EdgeInsets.symmetric(
      horizontal: T.s16,
      vertical: T.s12,
    ),
    this.glass = true,
  });

  final List<(String, String, String)> stats;
  final EdgeInsets padding;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final inner = Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 30,
              color: p.isDark
                  ? T.card.withValues(alpha: 0.16)
                  : T.taupe.withValues(alpha: 0.28),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ic.svg(stats[i].$1, color: p.accent, size: 17),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stats[i].$2,
                    style: Type.footnoteEmph(p).copyWith(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  stats[i].$3,
                  style: Type.caption(p),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ],
    );
    if (glass) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(T.rCard),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: T.glassBlur, sigmaY: T.glassBlur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: p.glassTint,
              borderRadius: BorderRadius.circular(T.rCard),
              border: Border.all(color: p.glassBorder),
            ),
            child: inner,
          ),
        ),
      );
    }
    return Padding(padding: padding, child: inner);
  }
}

/// Gallery thumbnail row with a "+N" overflow tile.
class GalleryRow extends StatelessWidget {
  const GalleryRow({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    const tile = 92.0;
    const gap = 8.0;
    // LayoutBuilder, not MediaQuery: it reports the width this row actually
    // gets, which is what must not overflow.
    return SizedBox(
      height: tile,
      child: LayoutBuilder(
        builder: (context, c) {
          final avail = c.maxWidth;
          final per = tile + gap;
          final maxWithOverflow = ((avail - tile) / per).floor().clamp(1, 4);
          final maxPlain = ((avail - gap) / per).floor().clamp(1, 4);
          final shown = count > maxWithOverflow ? maxWithOverflow : maxPlain;
          final hasOverflow = count > shown;
          return Row(
            children: [
              for (var i = 0; i < shown; i++) ...[
                PressScale(
                  onTap: onTap,
                  scale: 0.96,
                  child: Container(
                    width: tile,
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.divider),
                    ),
                    child: PetArt(
                      seed: i * 3 + 1,
                      radius: 14,
                      species: i.isEven ? Species.dog : Species.cat,
                    ),
                  ),
                ),
                const SizedBox(width: gap),
              ],
              if (hasOverflow)
                PressScale(
                  onTap: onTap,
                  child: Container(
                    width: tile,
                    decoration: BoxDecoration(
                      color: p.fieldBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.divider),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Ic.svg(Ic.plus, color: p.accent, size: 20, stroke: 2.2),
                        const SizedBox(height: 2),
                        Text('+${count - shown}', style: Type.footnoteEmph(p)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Deterministic warm illustration standing in for a pet photo — flat vector
/// art in the brand palette, never emoji and never a random stock image.
/// A pet's portrait: the owner's photo when there is one, the generated
/// [PetArt] otherwise.
///
/// Every surface that shows a pet should use this rather than [PetArt]
/// directly, so adding a photo updates the whole app at once.
class PetAvatar extends StatelessWidget {
  const PetAvatar({
    super.key,
    required this.pet,
    this.radius = 0,
    this.iconSize = 64,
    this.label,
    this.alignment = Alignment.center,
  });

  final Pet pet;
  final double radius;
  final double iconSize;
  final String? label;

  /// Medallion position for the no-photo fallback art. Ignored when the pet
  /// has a photo (the photo always fills).
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (!pet.hasPhoto) {
      return PetArt(
        seed: pet.id.hashCode.abs() % 4,
        species: pet.species,
        radius: radius,
        iconSize: iconSize,
        alignment: alignment,
        label: label ?? '${pet.name} portrait',
      );
    }
    return Semantics(
      image: true,
      label: label ?? 'Photo of ${pet.name}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          pet.photo!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => PetArt(
            seed: pet.id.hashCode.abs() % 4,
            species: pet.species,
            radius: radius,
            iconSize: iconSize,
            alignment: alignment,
            label: label ?? '${pet.name} portrait',
          ),
        ),
      ),
    );
  }
}

/// The owner avatar: their photo when set, otherwise their initials.
class OwnerAvatar extends StatelessWidget {
  const OwnerAvatar({
    super.key,
    required this.initials,
    required this.size,
    this.photo,
  });

  final String initials;
  final double size;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final has = photo != null && photo!.isNotEmpty;
    return Semantics(
      image: true,
      label: 'Profile photo of $initials',
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: has
              ? Image.memory(
                  photo!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => _initials(p, initials, size),
                )
              : _initials(p, initials, size),
        ),
      ),
    );
  }

  Widget _initials(AppPalette p, String text, double s) => Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: p.accent.withValues(alpha: 0.14),
      shape: BoxShape.circle,
      border: Border.all(color: p.accent.withValues(alpha: 0.35), width: 1.5),
    ),
    child: Text(text, style: Type.title2(p).copyWith(color: p.primaryFill)),
  );
}

/// Initials for an owner avatar: first letters of the first two name parts,
/// uppercased. Falls back to '?' when the name is empty.
String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  String firstOf(String s) => String.fromCharCode(s.runes.first).toUpperCase();
  if (parts.length == 1) return firstOf(parts.first);
  return '${firstOf(parts.first)}${firstOf(parts[1])}';
}

class PetArt extends StatelessWidget {
  const PetArt({
    super.key,
    required this.seed,
    this.species,
    this.radius = 0,
    this.iconSize = 64,
    this.label,
    this.alignment = Alignment.center,
  });

  final int seed;

  /// Draws the correct animal. Falls back to the seed only when a caller has
  /// no pet to hand.
  final Species? species;
  final double radius;
  final double iconSize;
  final String? label;

  /// Where the medallion sits in the box. Callers with overlaid bottom
  /// content (name/scrim) shift it up so it reads optically centred in the
  /// visible area rather than the geometric centre of the whole box.
  final AlignmentGeometry alignment;

  static const _tints = [
    Color(0xFFF7C98B), // amber
    Color(0xFFE4843E), // orange
    Color(0xFFC7AB83), // sand
    Color(0xFFF4AE52),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final tint = _tints[seed % _tints.length];
    final isDog = species == null ? seed.isEven : species == Species.dog;
    final path = isDog ? Ic.dog : Ic.cat;
    return Semantics(
      image: true,
      label: label ?? 'Illustration of a pet',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: 0.95),
                tint.withValues(alpha: 0.62),
              ],
            ),
          ),
          child: Align(
            alignment: alignment,
            child: Container(
              width: iconSize * 1.24,
              height: iconSize * 1.24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.cream.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              child: Ic.svg(
                path,
                color: p.isDark ? const Color(0xFF241B17) : T.espresso,
                size: iconSize * 0.86,
                stroke: 1.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Deterministic product tile art.
class ProductArt extends StatelessWidget {
  const ProductArt({super.key, required this.art, this.radius = 16, this.size});

  final int art;
  final double radius;
  final double? size;

  static const _icons = [
    Ic.bag, // dog food
    Ic.droplet, // wet pouch
    Ic.bone, // treats
    Ic.droplet, // shampoo
    Ic.scissors, // clippers
    Ic.pill, // spot-on
    Ic.bone, // rope toy
    Ic.shield, // harness
  ];

  static const _tints = [
    Color(0xFFFDEBD3),
    Color(0xFFFCE3C7),
    Color(0xFFF6E7D6),
    Color(0xFFFBEBD6),
    Color(0xFFFDF3E3),
    Color(0xFFF7DCBE),
    Color(0xFFF9E8D0),
    Color(0xFFFCEDDA),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: _tints[art % _tints.length],
        child: Center(
          child: Ic.svg(
            _icons[art % _icons.length],
            // Dark mode: the tiles stay light, so the icon needs the deep
            // terracotta (4.43:1 worst tint, was 1.19:1 with amber).
            color: p.isDark ? T.terracottaDeep : p.accent,
            size: (size ?? 80) * 0.42,
            stroke: 1.7,
          ),
        ),
      ),
    );
  }
}

/// Circular staff avatar (initials on a tinted disc).
class StaffAvatar extends StatelessWidget {
  const StaffAvatar({
    super.key,
    required this.initials,
    required this.size,
    this.role,
    this.badge = true,
  });

  final String initials;
  final double size;
  final StaffRole? role;
  final bool badge;

  static const _tints = {
    StaffRole.vet: Color(0xFFE4843E),
    StaffRole.vetAssistant: Color(0xFFC7AB83),
    StaffRole.groomer: Color(0xFF9B8A76),
  };

  @override
  Widget build(BuildContext context) {
    final color = role == null ? T.taupe : _tints[role!]!;
    return Semantics(
      image: true,
      label: role == null ? initials : '${role!.label} avatar',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            color: context.p.isDark ? T.amber : T.espresso,
          ),
        ),
      ),
    );
  }
}

/// Primary filled button — darkened terracotta fill + white text (5.84:1).
/// Falls back to an espresso fill with cream text on dark surfaces.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.destructive = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final bool busy;
  final bool expand;
  final bool destructive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final enabled = onPressed != null && !busy;
    final fill = destructive
        ? p.destructive
        : p.isDark
        ? T.amber
        : p.primaryFill;
    // Espresso on amber/dark fills — white text on the dark theme's amber
    // primaryFill would sit at ~2:1 and read as broken.
    final fg = p.isDark ? T.espresso : T.card;
    final h = compact ? 46.0 : 54.0;

    // IntrinsicHeight + minHeight (not a fixed height): at very large text
    // scales the label wraps to two lines and the button grows so it is never
    // clipped (AX5). At 1x the intrinsic height is the 54pt/46pt design
    // height, so rendering is unchanged.
    final child = IntrinsicHeight(
      child: Container(
        constraints: BoxConstraints(minHeight: h),
        padding: EdgeInsets.symmetric(horizontal: compact ? T.s16 : T.s20),
        decoration: BoxDecoration(
          color: enabled ? fill : fill.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(T.rControl + 2),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              CupertinoActivityIndicator(color: fg)
            else if (icon != null) ...[
              Ic.svg(icon!, color: fg, size: 19, stroke: 2.2),
              const SizedBox(width: 9),
            ],
            Flexible(
              child: Text(
                label,
                style: Type.button(p).copyWith(color: fg),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: enabled ? onPressed : null,
          child: expand
              ? SizedBox(width: double.infinity, child: child)
              : child,
        ),
      ),
    );
  }
}

/// Secondary (tinted) button used for tertiary paths.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final bool expand;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final fg = destructive ? p.destructive : p.accentText;
    // IntrinsicHeight + minHeight (not a fixed height): at very large text
    // scales the label wraps to two lines and the button grows so it is never
    // clipped (AX5). At 1x the intrinsic height is the 52pt design height,
    // so rendering is unchanged.
    final child = IntrinsicHeight(
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: T.s20),
        decoration: BoxDecoration(
          color: p.fieldBg,
          borderRadius: BorderRadius.circular(T.rControl + 2),
          border: Border.all(
            color: destructive
                ? p.destructive.withValues(alpha: 0.4)
                : p.accent.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Ic.svg(icon!, color: fg, size: 19, stroke: 2.1),
              const SizedBox(width: 9),
            ],
            Flexible(
              child: Text(
                label,
                style: Type.button(p).copyWith(color: fg),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onPressed,
          child: expand
              ? SizedBox(width: double.infinity, child: child)
              : child,
        ),
      ),
    );
  }
}

/// Floating bottom action bar.
///
/// A detached frosted pill rather than a full-width strip: it is inset from
/// every edge, rounded, and backed by a real [BackdropFilter] so whatever
/// scrolls behind it shows through. Always reachable and never truncated — when
/// the Dynamic Type scale is large the bar wraps to two full-width rows.
class StickyCta extends StatelessWidget {
  const StickyCta({
    super.key,
    required this.child,
    this.extra,
    this.bottomInset = 0,
  });

  final Widget child;
  final Widget? extra;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 520;
    return SafeArea(
      top: false,
      // The floating tab bar sits over the bottom of every route inside the
      // shell, pushed screens included, so lift clear of it. TabBarClearance is
      // provided above the tab Navigators, which is why it is visible here too.
      minimum: EdgeInsets.only(
        bottom: bottomInset + TabBarClearance.of(context),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 6, wide ? 24 : 14, 6),
        child: GlassCard(
          // Rounded enough to read as a floating object, not so round that a
          // wrapped second row looks like a pill. Padding stays tight on
          // purpose: the float comes from the inset margins, radius and
          // shadow, and every extra point here is content hidden above the fold.
          radius: 24,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              if (extra != null) ...[const SizedBox(height: 8), extra!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state with exactly one clear next action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: T.s24,
          vertical: compact ? T.s24 : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 64 : 84,
              height: compact ? 64 : 84,
              decoration: BoxDecoration(
                color: T.amber.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Ic.svg(
                  icon,
                  color: p.accent,
                  size: compact ? 30 : 38,
                  stroke: 1.7,
                ),
              ),
            ),
            SizedBox(height: compact ? T.s16 : T.s20),
            Text(title, style: Type.title2(p), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              style: Type.body(p).copyWith(color: p.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: T.s20),
              SizedBox(
                width: 260,
                child: PrimaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  icon: 'arrowRight',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quantified row: label on the left, value on the right, hairline divider.
class AmountRow extends StatelessWidget {
  const AmountRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.emphasis = false,
    this.note,
  });

  final String label;
  final String value;
  final bool bold;
  final bool emphasis;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final style = emphasis
        ? Type.title2(p)
        : bold
        ? Type.headline(p)
        : Type.body(p).copyWith(color: p.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: style),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: Type.caption(p)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// Money formatter — Philippine pesos.
String peso(num v) {
  final s = v is int ? v.toString() : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
  final parts = s.split('.');
  final buf = StringBuffer();
  final digits = parts.first;
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  if (parts.length > 1) buf.write('.${parts[1]}');
  return '₱$buf';
}

/// Haptic-style success feedback.
void successHaptic() => HapticFeedback.mediumImpact();

/// Haptic-style rejection feedback — a heavier thud than a success tap.
void errorHaptic() => HapticFeedback.heavyImpact();

/// Light tap feedback for ordinary controls.
void tapHaptic() => HapticFeedback.lightImpact();

/// Cupertino-friendly hairline divider. Flutter's Material `Divider` is not
/// imported anywhere in this app, so this keeps the tree Material-free.
class Divider extends StatelessWidget {
  const Divider({
    super.key,
    this.height = 1,
    this.thickness = 1,
    this.indent = 0,
    this.endIndent = 0,
    this.color,
  });

  final double height;
  final double thickness;
  final double indent;
  final double endIndent;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.p.divider;
    return SizedBox(
      height: height,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(left: indent, right: endIndent),
          child: Container(height: thickness, color: c),
        ),
      ),
    );
  }
}

/// Cupertino-style select dot (selected / unselected), SVG only.
class SelectDot extends StatelessWidget {
  const SelectDot({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    if (selected) {
      return Ic.svg(Ic.checkCircle, color: p.accent, size: 24, stroke: 2.1);
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: p.textSecondary, width: 1.6),
      ),
    );
  }
}
