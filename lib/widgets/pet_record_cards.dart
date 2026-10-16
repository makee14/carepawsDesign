import 'package:flutter/cupertino.dart';

import '../app.dart' show appRoute, dismissSheet, shortDate, showAppSheet;
import '../data/models.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import 'common.dart';

/// The ONE canonical implementation of the pet medical-record display
/// components (ponytail: share, don't duplicate). The customer pet profile
/// and the vet portal's pet detail both render through these — same models,
/// same cards. The vet surfaces additionally pass [showAudit] (timeline) or
/// rely on the audit captions that appear automatically when a record
/// carries audit fields; the customer build never stamps those fields, so it
/// renders byte-identical to before.

/// Shows a document's detail sheet: preview tile, kind/date/size line, and
/// the Download/Close actions.
void showDocSheet(BuildContext context, PetDoc d) {
  showAppSheet(
    context,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(T.s16, 8, T.s16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.name, style: Type.title1(context.p)),
          const SizedBox(height: 6),
          Text(
            '${d.kind} · issued ${shortDate(d.date)} · ${d.size} KB',
            style: Type.footnote(context.p),
          ),
          if (d.staffId != null && d.recordedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Recorded by ${d.staffId} · ${shortDate(d.recordedAt!)}',
              style: Type.caption(context.p)
                  .copyWith(color: context.p.textSecondary),
            ),
          ],
          const SizedBox(height: T.s16),
          DocPreview(doc: d),
          const SizedBox(height: T.s16),
          PrimaryButton(
            label: 'Download',
            icon: Ic.download,
            onPressed: () {
              dismissSheet(context);
              ScaffoldlessNotice.show(context, '${d.name} saved to Files.');
            },
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Close',
            onPressed: () => dismissSheet(context),
          ),
        ],
      ),
    ),
  );
}

/// Small shared notice used across profile/document sheets.
class ScaffoldlessNotice {
  static void show(BuildContext context, String message) {
    showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(T.s16, 8, T.s16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic.svg(
              Ic.checkCircle,
              color: context.p.success,
              size: 40,
              stroke: 1.9,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Type.headline(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: T.s16),
            PrimaryButton(label: 'OK', onPressed: () => dismissSheet(context)),
          ],
        ),
      ),
    );
  }
}

/// Document preview tile: the real scanned image when the doc has one,
/// tappable to a full-screen zoom viewer; otherwise the placeholder.
class DocPreview extends StatelessWidget {
  const DocPreview({super.key, required this.doc});

  final PetDoc doc;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final asset = doc.previewAsset;
    return Container(
      height: 260,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.fieldBg,
        borderRadius: BorderRadius.circular(T.rCard),
        border: Border.all(color: p.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: asset == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ic.svg(Ic.doc, color: p.accent, size: 42, stroke: 1.7),
                const SizedBox(height: 8),
                Text('Preview', style: Type.footnote(p)),
              ],
            )
          : Semantics(
              button: true,
              label: 'Preview of ${doc.name}. Activate to enlarge.',
              child: ExcludeSemantics(
                child: PressScale(
                  onTap: () =>
                      Navigator.of(context)
                          .push(appRoute(_DocViewerScreen(doc: doc))),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.asset(
                      asset,
                      fit: BoxFit.cover,
                      semanticLabel: 'Preview of ${doc.name}',
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Full-screen document viewer: pinch-zoom the scanned page, Close to
/// return to the document sheet.
class _DocViewerScreen extends StatelessWidget {
  const _DocViewerScreen({required this.doc});

  final PetDoc doc;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF000000),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF000000).withValues(alpha: 0.7),
        brightness: Brightness.dark,
        middle: Text(
          doc.name,
          style: const TextStyle(color: Color(0xFFFFFFFF)),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Semantics(
            button: true,
            label: 'Close document viewer',
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Center(
            child: Image.asset(
              doc.previewAsset!,
              fit: BoxFit.contain,
              semanticLabel: 'Enlarged preview of ${doc.name}',
            ),
          ),
        ),
      ),
    );
  }
}

/// The pet's vitals as tappable tiles; a tile opens the reading's detail
/// sheet. When the reading carries an audit trail, the sheet shows who
/// recorded it — historic/seed readings (no audit fields) render exactly as
/// before.
class VitalsGrid extends StatelessWidget {
  const VitalsGrid({super.key, required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final v in pet.vitals)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 40 - 12) / 2,
            child: SoftCard(
              padding: const EdgeInsets.all(14),
              onTap: () => _vitalDetail(context, v, pet),
              semanticLabel: '${v.label}: ${v.value} ${v.unit}',
              child: Row(
                children: [
                  Ic.svg(
                    Ic.byName(v.icon),
                    color: p.accent,
                    size: 22,
                    stroke: 1.9,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${v.value} ${v.unit}'.trim(),
                          style: Type.headline(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          v.label,
                          style: Type.caption(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _vitalDetail(BuildContext context, Vital v, Pet pet) {
    showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(T.s16, 8, T.s16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic.svg(
              Ic.byName(v.icon),
              color: context.p.accent,
              size: 36,
              stroke: 1.8,
            ),
            const SizedBox(height: 12),
            Text(v.label, style: Type.title2(context.p)),
            const SizedBox(height: 6),
            Text(
              '${v.value} ${v.unit}'.trim(),
              style: Type.largeTitle(context.p)
                  .copyWith(color: context.p.accentText),
            ),
            const SizedBox(height: 8),
            Text(
              v.value.trim() == '—' || v.value.trim().isEmpty
                  ? 'No reading yet — the clinic records this at ${pet.name}\u2019s first visit.'
                  : 'Recorded for ${pet.name} at the last clinic visit. Your vet updates these after each '
                        'examination.',
              style: Type.footnote(context.p),
              textAlign: TextAlign.center,
            ),
            if (v.staffId != null && v.recordedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Recorded by ${v.staffId} · ${shortDate(v.recordedAt!)}',
                style: Type.caption(context.p)
                    .copyWith(color: context.p.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: T.s16),
            PrimaryButton(
              label: 'Done',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// One medical-timeline card: role tag, date, title, detail, staff name.
/// When [showAudit] is true and the entry carries an audit trail, the card
/// additionally shows the staff id + recording timestamp — the vet portal's
/// accountability line. The customer passes false (default) and never sees
/// it.
class TimelineCard extends StatelessWidget {
  const TimelineCard({
    super.key,
    required this.entry,
    required this.pet,
    this.showAudit = false,
  });
  final TimelineEntry entry;
  final Pet pet;
  final bool showAudit;

  static const _roleIcon = {
    StaffRole.vet: Ic.heartPulse,
    StaffRole.vetAssistant: Ic.clipboard,
    StaffRole.groomer: Ic.scissors,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: () => _open(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Ic.svg(
                      _roleIcon[entry.role]!,
                      color: p.primaryFill,
                      size: 18,
                      stroke: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(width: 2, height: 34, color: p.divider),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Role-tagged: text label, never colour-only.
                      Flexible(
                        child: StatusChip(
                          label: entry.role.chip,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Flexible + ellipsis: at AX5 the date and the chip
                      // share the row instead of the date pushing past it.
                      Flexible(
                        child: Text(
                          shortDate(entry.date),
                          style: Type.caption(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(entry.title, style: Type.headline(p)),
                  const SizedBox(height: 4),
                  Text(entry.detail, style: Type.footnote(p)),
                  const SizedBox(height: 6),
                  Text(
                    entry.staffName,
                    style: Type.caption(p)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (showAudit &&
                      entry.staffId != null &&
                      entry.recordedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Recorded by ${entry.staffId} · ${shortDate(entry.recordedAt!)}',
                      style: Type.caption(p).copyWith(color: p.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(T.s16, 8, T.s16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusChip(label: entry.role.chip, compact: true),
                const Spacer(),
                Text(shortDate(entry.date), style: Type.caption(context.p)),
              ],
            ),
            const SizedBox(height: 12),
            Text(entry.title, style: Type.title1(context.p)),
            const SizedBox(height: 8),
            Text(entry.detail, style: Type.body(context.p)),
            const SizedBox(height: 14),
            Text(entry.staffName, style: Type.footnote(context.p)),
            if (showAudit &&
                entry.staffId != null &&
                entry.recordedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Recorded by ${entry.staffId} · ${shortDate(entry.recordedAt!)}',
                style: Type.caption(context.p)
                    .copyWith(color: context.p.textSecondary),
              ),
            ],
            const SizedBox(height: T.s16),
            PrimaryButton(
              label: 'Done',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}
