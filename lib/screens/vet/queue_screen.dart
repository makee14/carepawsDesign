import 'package:flutter/cupertino.dart';

import '../../app.dart'
    show
        LargeTitleBar,
        appRoute,
        countdownLabel,
        isToday,
        mediumDate,
        shortDate;
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import '../appointments/appointment_detail_screen.dart';
import '../chat_thread_screen.dart';
import '../shop/orders_screen.dart';
import 'widgets/queue_card.dart';

/// Urgency rank: user-shared triage handoffs (sick) > appointment requests
/// (today) > waiting chats > orders awaiting prep.
int _rank(VetQueueKind kind) => switch (kind) {
  VetQueueKind.triageHandoff => 0,
  VetQueueKind.appointmentRequest => 1,
  VetQueueKind.waitingChat => 2,
  VetQueueKind.order => 3,
};

/// Builds the vet's unified work queue from the shared store.
///
/// Sources (all shared models, never vet duplicates):
/// - triage handoffs: [ChatMessage]s with [ChatKind.triageHandoff] in the
///   clinic thread. The message IS the sharing record — [AppStore.handOffToClinic]
///   is the only thing that creates one, and it only runs when the customer
///   opts to share, so a triage result the customer never shared can never
///   appear here.
/// - appointment requests: [Appointment]s with [ApptStatus.requestPending],
///   today's first, then by start time.
/// - waiting chats: non-AI threads whose last non-system message is from the
///   customer (sentByMe) — staff have not replied yet. A thread already
///   surfaced as a triage handoff is not duplicated here; longest-waiting
///   first.
/// - orders awaiting prep: [Order]s with [OrderStatus.paid], newest first.
List<VetQueueItem> buildVetQueue(AppStore store) {
  final now = store.now;
  final items = <VetQueueItem>[];

  // --- triage handoffs ------------------------------------------------------
  final handoffs =
      store.messages.where((m) => m.kind == ChatKind.triageHandoff).toList()
        ..sort((a, b) => b.at.compareTo(a.at));
  final handoffThreads = <String>{};
  for (final m in handoffs) {
    handoffThreads.add(m.threadId);
    final pet = m.petId == null ? null : store.pet(m.petId!);
    items.add(
      VetQueueItem(
        id: 'handoff-${m.id}',
        kind: VetQueueKind.triageHandoff,
        title: pet?.name ?? 'Health check',
        subtitle: 'Shared by ${store.ownerFirstName}',
        detail: m.triageSummary ?? m.text,
        chipLabel: 'Triage handoff',
        timeLabel: _agoLabel(m.at, now),
        at: m.at,
        threadId: m.threadId,
        petId: m.petId,
        triageSummary: m.triageSummary,
      ),
    );
  }

  // --- appointment requests -------------------------------------------------
  final requests = store.appointments
      .where((a) => a.status == ApptStatus.requestPending)
      .toList();
  for (final a in requests) {
    final pet = store.pet(a.petId);
    final service = store.serviceOf(a.serviceId);
    items.add(
      VetQueueItem(
        id: 'request-${a.id}',
        kind: VetQueueKind.appointmentRequest,
        title: '${pet?.name ?? 'Pet'} · ${service.name}',
        subtitle: mediumDate(a.start),
        chipLabel: 'Request pending',
        timeLabel: countdownLabel(now, a.start),
        at: a.start,
        appointmentId: a.id,
        petId: a.petId,
      ),
    );
  }

  // --- waiting chats ----------------------------------------------------------
  for (final thread in Seed.threads.where((t) => !t.isAi)) {
    if (handoffThreads.contains(thread.id)) continue;
    final threadMessages = store.messages
        .where((m) => m.threadId == thread.id && m.kind != ChatKind.system)
        .toList();
    if (threadMessages.isEmpty) continue;
    threadMessages.sort((a, b) => a.at.compareTo(b.at));
    final last = threadMessages.last;
    if (!last.sentByMe) continue;
    final snippet = last.text.isEmpty ? 'Photo' : last.text;
    items.add(
      VetQueueItem(
        id: 'chat-${thread.id}',
        kind: VetQueueKind.waitingChat,
        title: thread.title,
        subtitle: '${store.ownerFirstName}: $snippet',
        chipLabel: 'Waiting reply',
        timeLabel: _agoLabel(last.at, now),
        at: last.at,
        threadId: thread.id,
      ),
    );
  }

  // --- orders awaiting prep ---------------------------------------------------
  final orders =
      store.orders.where((o) => o.status == OrderStatus.paid).toList()
        ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
  for (final o in orders) {
    final count = o.lines.fold(0, (n, l) => n + l.qty);
    items.add(
      VetQueueItem(
        id: 'order-${o.id}',
        kind: VetQueueKind.order,
        title: 'Order ${o.pickupCode}',
        subtitle: '$count item${count == 1 ? '' : 's'} · ${peso(o.total)}',
        detail: o.status.label,
        chipLabel: 'To prepare',
        timeLabel: _agoLabel(o.placedAt, now),
        at: o.placedAt,
        orderId: o.id,
      ),
    );
  }

  items.sort((a, b) => _compare(a, b, now));
  return items;
}

int _compare(VetQueueItem a, VetQueueItem b, DateTime now) {
  final r = _rank(a.kind).compareTo(_rank(b.kind));
  if (r != 0) return r;
  return switch (a.kind) {
    // Today's requests first, then by start time.
    VetQueueKind.appointmentRequest => _compareRequests(a, b, now),
    // Longest-waiting chat first.
    VetQueueKind.waitingChat => a.at.compareTo(b.at),
    // Newest demand first.
    _ => b.at.compareTo(a.at),
  };
}

/// Comparator for appointment requests: today's requests first, then the
/// earliest start. `false < true`, so a same-day request sorts before a
/// future one.
int _compareRequests(VetQueueItem a, VetQueueItem b, DateTime now) {
  final aToday = isToday(a.at, now);
  final bToday = isToday(b.at, now);
  if (aToday != bToday) return aToday ? -1 : 1;
  return a.at.compareTo(b.at);
}

String _agoLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.isNegative || d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return shortDate(at);
}

/// QUEUE — the vet's home: the triaged work queue.
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  void _open(BuildContext context, VetQueueItem item) {
    final page = switch (item.kind) {
      VetQueueKind.triageHandoff => ChatThreadScreen(
        threadId: item.threadId!,
        openedWithPetId: item.petId,
        triageSummary: item.triageSummary,
        replyRole: StaffRole.vet,
      ),
      VetQueueKind.appointmentRequest => AppointmentDetailScreen(
        appointmentId: item.appointmentId!,
      ),
      VetQueueKind.waitingChat => ChatThreadScreen(
        threadId: item.threadId!,
        replyRole: StaffRole.vet,
      ),
      // No standalone order-detail screen exists in the codebase: the orders
      // list's card is the order detail (lines, totals, refund actions).
      VetQueueKind.order => const OrdersScreen(),
    };
    Navigator.of(context).push(appRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final items = buildVetQueue(store);

    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Queue'),
          if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Ic.checkCircle,
                title: 'All caught up',
                body: 'New appointment requests, chats, orders and shared health checks will land here.',
              ),
            )
          else ...[
            for (final section in _sections(items)) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, 0),
                  child: SectionHeader(
                    title: '${section.title} · ${section.items.length}',
                    padding: const EdgeInsets.only(top: T.s16, bottom: T.s8),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, T.s12),
                sliver: SliverList.separated(
                  itemCount: section.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: T.s12),
                  itemBuilder: (context, i) {
                    final item = section.items[i];
                    return QueueCard(
                      key: ValueKey(item.id),
                      item: item,
                      onTap: () => _open(context, item),
                    );
                  },
                ),
              ),
            ],
            // Room for the floating tab bar under the last section.
            SliverToBoxAdapter(
              child: SizedBox(height: TabBarClearance.of(context)),
            ),
          ],
        ],
      ),
    );
  }
}

@immutable
class _Section {
  const _Section(this.title, this.items);
  final String title;
  final List<VetQueueItem> items;
}

/// Groups the sorted queue into its urgency-ordered sections.
List<_Section> _sections(List<VetQueueItem> items) {
  const titles = {
    VetQueueKind.triageHandoff: 'Triage handoffs',
    VetQueueKind.appointmentRequest: 'Appointment requests',
    VetQueueKind.waitingChat: 'Chats waiting',
    VetQueueKind.order: 'Orders to prepare',
  };
  final sections = <_Section>[];
  for (final kind in VetQueueKind.values) {
    final group = items.where((i) => i.kind == kind).toList();
    if (group.isNotEmpty) sections.add(_Section(titles[kind]!, group));
  }
  return sections;
}
