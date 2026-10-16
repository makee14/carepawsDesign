import 'package:flutter/cupertino.dart';

import '../../app.dart' show LargeTitleBar, appRoute, shortDate;
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import '../chat_thread_screen.dart';

/// One inbox row per clinic thread. Built by [buildVetInbox] from the shared
/// models — presentational only, never reaches into the store itself.
@immutable
class VetInboxItem {
  const VetInboxItem({
    required this.threadId,
    required this.title,
    required this.preview,
    required this.timeLabel,
    required this.at,
    required this.unread,
    this.pet,
    this.triageSummary,
  });

  final String threadId;

  /// "Customer · pet" — precomputed display strings so the row stays
  /// presentational.
  final String title;
  final String preview;
  final String timeLabel;

  /// The thread's most recent activity, used for sorting.
  final DateTime at;

  /// [AppStore.vetUnread]: customer-side messages newer than the vet's read
  /// marker.
  final int unread;

  /// The thread's pet when one is attached (latest message's petId, else the
  /// handoff's) — drives the row avatar and the thread's pet context.
  final Pet? pet;

  /// The thread's latest [ChatKind.triageHandoff] summary, surfaced from the
  /// message itself — never re-derived. Null when the customer never shared.
  final String? triageSummary;
}

/// Builds the vet's clinic inbox: every clinic thread (the customer app shows
/// one thread; the vet sees them all), sorted by most-recent activity.
///
/// Sources (all shared models, never vet duplicates — the same contract the
/// queue uses):
/// - threads: non-AI threads from [Seed]. Callers may pass their own list;
///   the backend swap will supply all customer threads through it.
/// - unread: [AppStore.vetUnread] — customer-side messages newer than the
///   vet's read marker.
/// - handoff context: the thread's latest [ChatKind.triageHandoff] message.
///   The message IS the sharing record — [AppStore.handOffToClinic] is the
///   only thing that creates one, and only on the customer's explicit share —
///   so the summary is surfaced from it, never re-derived.
List<VetInboxItem> buildVetInbox(AppStore store, {List<Thread>? threads}) {
  final source = threads ?? Seed.threads.where((t) => !t.isAi).toList();
  final items = <VetInboxItem>[];
  for (final thread in source.where((t) => !t.isAi)) {
    final msgs = store.messages.where((m) => m.threadId == thread.id).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final visible = msgs.where((m) => m.kind != ChatKind.system).toList();
    final last = visible.isEmpty ? null : visible.last;
    ChatMessage? handoff;
    for (final m in msgs) {
      if (m.kind == ChatKind.triageHandoff) handoff = m;
    }
    final petId = last?.petId ?? handoff?.petId;
    final pet = petId == null ? null : store.pet(petId);
    final customer = store.ownerFirstName;
    items.add(
      VetInboxItem(
        threadId: thread.id,
        title: pet == null ? customer : '$customer · ${pet.name}',
        preview: _preview(last),
        timeLabel: last == null ? '' : _agoLabel(last.at, store.now),
        at: last?.at ?? DateTime.fromMillisecondsSinceEpoch(0),
        unread: store.vetUnread(thread.id),
        pet: pet,
        triageSummary: handoff?.triageSummary,
      ),
    );
  }
  items.sort((a, b) => b.at.compareTo(a.at));
  return items;
}

/// Filters inbox rows by customer or pet name — the vet needs to find threads
/// fast. Case-insensitive; an empty query returns everything.
List<VetInboxItem> filterVetInbox(List<VetInboxItem> items, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return items;
  return items.where((i) => i.title.toLowerCase().contains(q)).toList();
}

String _preview(ChatMessage? last) {
  if (last == null) return 'No messages yet';
  if (last.kind == ChatKind.image) return 'Photo';
  if (last.kind == ChatKind.triageHandoff) return 'Health check shared';
  return last.text;
}

String _agoLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.isNegative || d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return shortDate(at);
}

/// CHATS — the full clinic inbox across all customers (the customer app sees
/// one thread; the vet sees every thread). Reuses [ChatThreadScreen] for the
/// thread view — no duplicate chat UI.
class VetChatsScreen extends StatefulWidget {
  const VetChatsScreen({super.key});

  @override
  State<VetChatsScreen> createState() => _VetChatsScreenState();
}

class _VetChatsScreenState extends State<VetChatsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(VetInboxItem item) {
    // The vet has seen the thread — move the inbox's read marker before
    // pushing, so returning to the inbox shows no badge.
    AppScope.read(context).markVetThreadRead(item.threadId);
    Navigator.of(context).push(
      appRoute(
        ChatThreadScreen(
          threadId: item.threadId,
          openedWithPetId: item.pet?.id,
          triageSummary: item.triageSummary,
          replyRole: StaffRole.vet,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final items = filterVetInbox(buildVetInbox(store), _search.text);
    final searching = _search.text.trim().isNotEmpty;

    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Chats'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, T.s12),
              // 44pt floor at 1x, scaled (clamped 1.6x) so large Dynamic Type
              // doesn't clip the field's text.
              child: SizedBox(
                height: Layout.scale(context, 44),
                child: CupertinoSearchTextField(
                  controller: _search,
                  placeholder: 'Search customers or pets',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Ic.chat,
                title: searching ? 'No matching chats' : 'No chats yet',
                body: searching
                    ? 'Try a different customer or pet name.'
                    : 'Customer chats with the clinic team will land here.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, T.s12),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: T.s12),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return VetInboxRow(
                    key: ValueKey(item.threadId),
                    item: item,
                    onTap: () => _open(item),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(height: TabBarClearance.of(context)),
          ),
        ],
      ),
    );
  }
}

/// One shared inbox-row layout (ponytail: one layout, content slots). The
/// whole card is the tap target — well above the 44pt minimum.
class VetInboxRow extends StatelessWidget {
  const VetInboxRow({super.key, required this.item, required this.onTap});

  final VetInboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final item = this.item;
    // AX5: the header reflows instead of hiding behind "Mar…". The title
    // takes the full row width and wraps, the time + unread badge drop into
    // a row beneath it, and the preview goes full-width below the header.
    // Scale-gated so 1x is byte-identical.
    final big = MediaQuery.textScalerOf(context).scale(1) > 1.0;
    final unreadLabel = item.unread == 0 ? '' : ', ${item.unread} unread';

    return SoftCard(
      onTap: onTap,
      semanticLabel: '${item.title}. ${item.preview}$unreadLabel',
      padding: const EdgeInsets.all(T.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: item.pet == null
                    ? Container(
                        decoration: BoxDecoration(
                          color: p.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Ic.svg(
                            Ic.chat,
                            color: p.accent,
                            size: 22,
                            stroke: 2,
                          ),
                        ),
                      )
                    : PetAvatar(
                        pet: item.pet!,
                        radius: 22,
                        iconSize: 22,
                        label: '${item.pet!.name} portrait',
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: Type.headline(p),
                      maxLines: big ? null : 1,
                      overflow: big ? null : TextOverflow.ellipsis,
                    ),
                    if (big &&
                        (item.timeLabel.isNotEmpty || item.unread > 0)) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.timeLabel.isNotEmpty)
                            Text(
                              item.timeLabel,
                              style: Type.caption(p)
                                  .copyWith(color: p.textSecondary),
                            ),
                          if (item.timeLabel.isNotEmpty && item.unread > 0)
                            const SizedBox(width: 8),
                          if (item.unread > 0) _UnreadBadge(count: item.unread),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 3),
                      Text(
                        item.preview,
                        style: Type.footnote(p)
                            .copyWith(color: p.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!big) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.timeLabel.isNotEmpty)
                      Text(
                        item.timeLabel,
                        style: Type.caption(p).copyWith(color: p.textSecondary),
                      ),
                    if (item.unread > 0) ...[
                      const SizedBox(height: 6),
                      _UnreadBadge(count: item.unread),
                    ],
                  ],
                ),
              ],
            ],
          ),
          if (big) ...[
            const SizedBox(height: 6),
            Text(
              item.preview,
              style: Type.footnote(p).copyWith(color: p.textSecondary),
            ),
          ],
          // The handoff context banner: the customer-shared triage summary,
          // surfaced from the handoff message — never re-derived.
          if (item.triageSummary != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: T.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(T.rControl),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Ic.svg(
                      Ic.sparkle,
                      color: p.accentText,
                      size: 16,
                      stroke: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const StatusChip(
                          label: 'Triage handoff',
                          compact: true,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.triageSummary!,
                          style: Type.footnote(p).copyWith(color: p.text),
                        ),
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

/// Unread pill: white on the same signal red the tab-bar badge uses
/// (≥4.5:1 contrast), ≥20pt so the count stays legible. The row is the tap
/// target; the badge is a graphic, so the semantics label carries the count.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count unread',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
