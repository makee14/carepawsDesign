import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import 'chat_thread_screen.dart';

/// CHATS — a single inbox. No presence system, no live availability badges.
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final offline = store.offlineNote;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Chats'),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
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
                SectionHeader(
                  title: 'Clinic team',
                  icon: Ic.person,
                  actionLabel: 'All staff',
                  onAction: () =>
                      showAppSheet(context, child: const StaffDirectorySheet()),
                ),
                const StaffDirectory(compact: true),
                const SizedBox(height: T.s20),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Ic.svg(Ic.info, color: p.textSecondary, size: 18),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'How this works',
                              style: Type.headline(p),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CarePaws AI is the clinic\'s in-app assistant — feeding, health, vaccines, '
                        'grooming and health checks. It gives guidance, never a diagnosis. Anything '
                        'outside veterinary care it will turn back to your pet. Anything clinical goes '
                        'to Miguel the vet assistant, who loops in Dr. Alvarez or Ana when needed. '
                        'A health check carries your pet and the summary automatically — no retyping.',
                        style: Type.body(p).copyWith(color: p.textSecondary),
                      ),
                    ],
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
                              maxLines: 1,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                                    child: Text(
                                      thread.badge!,
                                      style: Type.caption(p),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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

class StaffDirectorySheet extends StatelessWidget {
  const StaffDirectorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clinic team', style: Type.title1(p)),
          const SizedBox(height: 6),
          Text(
            'Miguel the vet assistant owns this inbox and loops in Dr. Alvarez or Ana as needed.',
            style: Type.footnote(p),
          ),
          const SizedBox(height: T.s16),
          const StaffDirectory(),
          const SizedBox(height: T.s20),
          PrimaryButton(label: 'Done', onPressed: () => dismissSheet(context)),
        ],
      ),
    );
  }
}
