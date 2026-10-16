import 'package:flutter/cupertino.dart';

import '../../../design/icons.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../widgets/common.dart';

/// The four kinds of demand in the vet work queue, in urgency order:
/// user-shared triage handoffs (sick) > appointment requests (today) >
/// waiting chats > orders awaiting prep.
enum VetQueueKind { triageHandoff, appointmentRequest, waitingChat, order }

/// One row in the vet work queue. Built by [buildVetQueue] (queue_screen.dart)
/// from the shared models — the card never reaches into the store itself.
@immutable
class VetQueueItem {
  const VetQueueItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.detail,
    required this.chipLabel,
    required this.timeLabel,
    required this.at,
    this.threadId,
    this.appointmentId,
    this.orderId,
    this.petId,
    this.triageSummary,
  });

  final String id;
  final VetQueueKind kind;

  /// Identifying info: pet name, owner, time/type — precomputed display
  /// strings so the card stays presentational.
  final String title;
  final String subtitle;

  /// Optional third line (e.g. the triage summary).
  final String? detail;
  final String chipLabel;
  final String timeLabel;

  /// The demand's timestamp, used for within-section sorting.
  final DateTime at;

  // Routing targets — exactly one is set, chosen by [kind].
  final String? threadId;
  final String? appointmentId;
  final String? orderId;
  final String? petId;
  final String? triageSummary;
}

/// One shared card layout for every queue item type (ponytail: one layout,
/// type-specific content slots). The whole card is the tap target — well
/// above the 44pt minimum.
class QueueCard extends StatelessWidget {
  const QueueCard({super.key, required this.item, required this.onTap});

  final VetQueueItem item;
  final VoidCallback onTap;

  (String icon, Color tint) _slot(AppPalette p) => switch (item.kind) {
    VetQueueKind.triageHandoff => (Ic.sparkle, p.accentText),
    VetQueueKind.appointmentRequest => (Ic.calendar, p.accentText),
    VetQueueKind.waitingChat => (Ic.chat, p.accentText),
    VetQueueKind.order => (Ic.bag, p.accentText),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final (icon, tint) = _slot(p);
    final item = this.item;
    return SoftCard(
      onTap: onTap,
      semanticLabel: '${item.chipLabel}: ${item.title}. ${item.subtitle}',
      padding: const EdgeInsets.all(T.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(T.rControl),
            ),
            child: Center(child: Ic.svg(icon, color: tint, size: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Type.headline(p),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: Type.subheadline(p).copyWith(color: p.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.detail!,
                    style: Type.footnote(p).copyWith(color: p.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                // Wrap, not Row: at AX5 the chip + time label reflow to two
                // lines instead of pushing past the screen edge.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(label: item.chipLabel, compact: true),
                    Text(
                      item.timeLabel,
                      style: Type.footnote(p).copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Ic.svg(
              Ic.chevronRight,
              color: p.textSecondary,
              size: 16,
              stroke: 2.4,
            ),
          ),
        ],
      ),
    );
  }
}
