import 'package:flutter/cupertino.dart';

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
import 'chat_thread_screen.dart';

/// CHATS — a single inbox. No presence system, no live availability badges.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  /// "How it works" starts collapsed (G2); the info icon expands it.
  bool _howItWorksOpen = false;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final offline = store.offlineNote;
    final reduce = reduceMotionOf(context);

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Chats'),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              T.s16,
              12,
              T.s16,
              40 + TabBarClearance.of(context),
            ),
            sliver: SliverList.list(
              children: [
                SoftCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ThreadRow(
                        thread: Seed.aiThread,
                        store: store,
                        highlighted: true,
                      ),
                      Divider(height: 1, color: p.divider, indent: 60),
                      _ThreadRow(thread: Seed.clinicThread, store: store),
                    ],
                  ),
                ),
                if (offline != null) ...[
                  const SizedBox(height: 12),
                  _OfflineNote(text: offline),
                ],
                const SizedBox(height: T.s20),
                // ---- Clinic chat section: how-it-works (G2, collapsed) +
                // clinic team carousel below it.
                Row(
                  children: [
                    Expanded(child: Text('Clinic chat', style: Type.title3(p))),
                    Semantics(
                      button: true,
                      container: true,
                      label: _howItWorksOpen
                          ? 'Hide how clinic chat works'
                          : 'How clinic chat works',
                      child: ExcludeSemantics(
                        child: PressScale(
                          onTap: () => setState(
                            () => _howItWorksOpen = !_howItWorksOpen,
                          ),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Ic.svg(
                              Ic.info,
                              color: T.taupe,
                              size: 20,
                              stroke: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: _howItWorksOpen
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Text(
                            'Message the clinic team directly. A vet, vet '
                            'assistant, or groomer replies during clinic hours '
                            '(${Clinic.hoursRangeLabel}). For emergencies after hours, call '
                            'the clinic number.',
                            style: Type.footnote(p)
                                .copyWith(color: p.textSecondary),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                const _TeamCarousel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal clinic-team carousel: 132×168 cards with photo, name, role.
/// Tap opens the member's profile sheet.
class _TeamCarousel extends StatefulWidget {
  const _TeamCarousel();

  @override
  State<_TeamCarousel> createState() => _TeamCarouselState();
}

class _TeamCarouselState extends State<_TeamCarousel> {
  PageController? _pages;
  double _vpWidth = 0;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The sliver insets 20pt on each side; one 132pt card + 12pt gap per page.
    final vp = MediaQuery.sizeOf(context).width - 40;
    if (_pages == null || (_vpWidth - vp).abs() > 0.5) {
      _pages?.dispose();
      _pages = PageController(viewportFraction: 144 / vp);
      _vpWidth = vp;
    }
    return SizedBox(
      height: 184,
      child: PageView.builder(
        controller: _pages,
        padEnds: false,
        itemCount: Seed.staff.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _TeamCard(member: Seed.staff[i]),
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.member});
  final Staff member;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      label: '${member.name}, ${member.role.label}',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: () => _openMemberSheet(context, member),
          child: Container(
            width: 132,
            height: 168,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(T.rControl),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TeamAvatar(initials: member.initials, size: 64),
                const SizedBox(height: 8),
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ).copyWith(color: p.text),
                  // Two lines at large Dynamic Type; one line at 1x.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  member.role.label,
                  style: const TextStyle(fontSize: 12)
                      .copyWith(color: p.textSecondary),
                  // Two lines at large Dynamic Type; one line at 1x.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Initials avatar for the team carousel/sheet: orange→terracotta gradient
/// disc, white initials. No photo assets (deliberate, per plan).
class _TeamAvatar extends StatelessWidget {
  const _TeamAvatar({required this.initials, required this.size});
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [T.orange, T.terracotta],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.375,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFFFFFFF),
        ),
      ),
    );
  }
}

/// Member profile sheet: bio, role, focus, and a Chat button that opens the
/// clinic thread with that member's reply voice.
///
/// Detents at 60%/92% (draggable), 40% scrim, dismiss on scrim tap or
/// drag-down. Built on showGeneralDialog + DraggableScrollableSheet rather
/// than showModalBottomSheet: the app root is a CupertinoApp, which provides
/// no MaterialLocalizations, so the Material sheet API throws here.
void _openMemberSheet(BuildContext context, Staff member) {
  final p = context.p;
  final reduce = reduceMotionOf(context);
  showGeneralDialog(
    context: context,
    barrierColor: const Color(0x66000000),
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    useRootNavigator: false,
    transitionDuration: reduce
        ? Duration.zero
        : const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, _) => SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.25,
          maxChildSize: 0.92,
          expand: false,
          snap: true,
          snapSizes: const [0.6, 0.92],
          builder: (sheetCtx, scrollController) =>
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (n) {
                  if (n.extent <= 0.26) Navigator.of(sheetCtx).pop();
                  return false;
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        12,
                        24,
                        24 + MediaQuery.paddingOf(sheetCtx).bottom,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: T.taupe.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _TeamAvatar(initials: member.initials, size: 80),
                          const SizedBox(height: 12),
                          Text(
                            member.name,
                            style: Type.title2(p),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: T.amber.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(T.rPill),
                            ),
                            child: Text(
                              member.role.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: T.text,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            member.bio,
                            style: Type.callout(p)
                                .copyWith(color: p.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            member.focus,
                            style: Type.footnote(p)
                                .copyWith(color: p.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          PrimaryButton(
                            label: 'Chat',
                            onPressed: () {
                              Navigator.of(sheetCtx).pop();
                              Navigator.of(context).push(
                                appRoute(
                                  ChatThreadScreen(
                                    threadId: Seed.clinicThread.id,
                                    replyRole: member.role,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      if (reduce) return child;
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.thread,
    required this.store,
    this.highlighted = false,
  });

  final Thread thread;
  final AppStore store;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final msgs = store.thread(thread.id);
    final last = msgs.isEmpty ? null : msgs.last;
    final lastLabel = last == null
        ? 'No messages yet'
        : last.kind == ChatKind.image
        ? 'Last message: a photo'
        : 'Last message: ${last.text}';
    final preview = thread.isAi
        ? 'Answers feeding, grooming, vaccines and general care.'
        : (store.offlineNote ??
              'Replies in about 10 minutes during clinic hours.');

    return Semantics(
      button: true,
      label: '${thread.title}. ${thread.subtitle}. $lastLabel',
      child: ExcludeSemantics(
        child: PressScale(
          scale: 0.985,
          onTap: () =>
              Navigator.of(context)
                  .push(appRoute(ChatThreadScreen(threadId: thread.id))),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: thread.isAi
                        ? T.amber.withValues(alpha: 0.24)
                        : p.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Ic.svg(
                      Ic.byName(thread.icon),
                      color: thread.isAi ? p.primaryFill : p.accent,
                      size: 22,
                      stroke: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              thread.title,
                              style: Type.headline(p),
                              // Two lines at large Dynamic Type so the title
                              // wraps instead of hiding behind "CarePa…".
                              // One line at 1x — every title fits.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (thread.pinned) ...[
                            const SizedBox(width: 6),
                            Ic.svg(
                              Ic.bookmark,
                              color: p.accent,
                              size: 14,
                              stroke: 2.2,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preview,
                        style: Type.footnote(p),
                        // Unbounded: the preview is short (≤2 lines at 1x),
                        // so 1x is untouched and AX5 reflows instead of
                        // hiding the reply promise behind an ellipsis.
                      ),
                      if (thread.isAi || thread.badge != null) ...[
                        const SizedBox(height: 6),
                        thread.isAi
                            ? StatusChip(
                                label: 'AI · Always available',
                                icon: Ic.sparkle,
                                compact: true,
                              )
                            : Row(
                                children: [
                                  Ic.svg(
                                    Ic.clock,
                                    color: p.textSecondary,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    // Unbounded: one line at 1x, so 1x is
                                    // untouched and AX5 reflows instead of
                                    // hiding the badge behind an ellipsis.
                                    child: Text(
                                      thread.badge!,
                                      style: Type.caption(p),
                                    ),
                                  ),
                                ],
                              ),
                      ],
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
          ),
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ic.svg(Ic.clock, color: p.accentText, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Type.footnote(p).copyWith(color: p.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// Staff directory — photo/avatar, name, role. No availability badges.
/// (Kept for the inline team list inside the clinic thread.)
class StaffDirectory extends StatelessWidget {
  const StaffDirectory({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < Seed.staff.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.divider, indent: 70),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  StaffAvatar(
                    initials: Seed.staff[i].initials,
                    size: 42,
                    role: Seed.staff[i].role,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Seed.staff[i].name, style: Type.headline(p)),
                        const SizedBox(height: 2),
                        Text(Seed.staff[i].role.label, style: Type.footnote(p)),
                        if (!compact)
                          Text(Seed.staff[i].focus, style: Type.caption(p)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
