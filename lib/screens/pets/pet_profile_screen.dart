import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import '../appointments/book_flow.dart';
import '../chat_thread_screen.dart';
import '../edit_pet_screen.dart';
import '../triage_screen.dart';

/// Pet Profile: photo hero + floating vitals card, vitals grid, timeline with
/// role-tagged entries, and documents.
class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({super.key, required this.petId});
  final String petId;

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  String _timelineFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final pet = store.pet(widget.petId);

    if (pet == null) {
      return CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: const DetailNavBar(title: 'Pet'),
        child: EmptyState(
          icon: Ic.paw,
          title: 'Pet not found',
          body: 'This pet is no longer on the account. Add them again from the Home tab.',
        ),
      );
    }

    final entries =
        pet.timeline
            .where(
              (e) => _timelineFilter == 'all' || e.role.chip == _timelineFilter,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: pet.name,
        actions: [
          IconTap(
            path: Ic.pencil,
            label: 'Edit ${pet.name}',
            color: p.primaryFill,
            onPressed: () =>
                Navigator.of(context)
                    .push(appRoute(EditPetScreen(petId: pet.id))),
          ),
          const SizedBox(width: 4),
          IconTap(
            path: Ic.chat,
            label: 'Chat about ${pet.name}',
            color: p.primaryFill,
            onPressed: () => Navigator.of(context).push(
              appRoute(
                ChatThreadScreen(
                  threadId: 'th_clinic',
                  openedWithPetId: pet.id,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  // Photo hero with floating vitals card — structural overlap: the
                  // Column (spacer + card) sizes the hero in normal flow; the
                  // photo is a fixed-size slot painted behind. Nothing
                  // overflows, so no ancestor can clip the card.
                  Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: Layout.heroHeight(context, 250),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(T.rCard),
                                child: PetAvatar(
                                  pet: pet,
                                  iconSize: 160,
                                  label: '${pet.name} portrait',
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              top: 12,
                              child: StatusChip(
                                label: '${pet.breed} · ${pet.sex}',
                                icon: pet.species == Species.dog
                                    ? Ic.dog
                                    : Ic.cat,
                                fg: T.espresso,
                                bg: T.cream.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: Layout.heroHeight(context, 250) - 34,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(T.s16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          pet.name,
                                          style: Type.title1(p),
                                        ),
                                      ),
                                      StatusChip(
                                        label: pet.ageLabel,
                                        compact: true,
                                        fg: p.accentText,
                                        bg: p.accent.withValues(alpha: 0.12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // The hero strip keeps weight only: temperature
                                  // and heart rate duplicate the Vitals section
                                  // below, and weight is dropped from the stat
                                  // strip further down so it is not shown twice.
                                  _VitalsInline(
                                    vitals: pet.vitals
                                        .where((v) => v.icon == 'scale')
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: T.s16),

                  // Stat strip
                  StatStrip(
                    stats: [
                      (
                        Ic.paw,
                        pet.species == Species.dog ? 'Dog' : 'Cat',
                        'Type',
                      ),
                      (Ic.doc, '${pet.docs.length}', 'Documents'),
                    ],
                  ),
                  const SizedBox(height: T.s16),

                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Book visit',
                          icon: Ic.calendar,
                          onPressed: () => Navigator.of(context)
                              .push(appRoute(BookFlow(initialPetId: pet.id))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Health check',
                          icon: Ic.sparkle,
                          onPressed: () => Navigator.of(context).push(
                            appRoute(
                              TriageScreen(
                                entry: TriageEntry.home,
                                preselectedPetId: pet.id,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: T.s20),
                  Text('Details', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        AmountRow(label: 'Breed', value: pet.breed, bold: true),
                        AmountRow(label: 'Sex', value: pet.sex),
                        AmountRow(
                          label: 'Born',
                          value:
                              '${shortDate(pet.birthDate)}, ${pet.birthDate.year}',
                        ),
                        AmountRow(
                          label: 'Weight',
                          value: '${pet.weightKg} kg',
                          bold: true,
                        ),
                        AmountRow(label: 'Microchip', value: pet.microchip),
                        AmountRow(
                          label: 'Allergies',
                          value: pet.allergies.isEmpty
                              ? 'None known'
                              : pet.allergies.join(', '),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: T.s20),
                  Text('Vitals', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  _VitalsGrid(pet: pet),

                  const SizedBox(height: T.s20),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Timeline', style: Type.headline(p)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterPill(
                          label: 'All pets',
                          selected: _timelineFilter == 'all',
                          onTap: () => setState(() => _timelineFilter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        for (final role in StaffRole.values) ...[
                          FilterPill(
                            label: role.short,
                            selected: _timelineFilter == role.chip,
                            onTap: () =>
                                setState(() => _timelineFilter = role.chip),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    SoftCard(
                      child: Text(
                        'No ${_timelineFilter == 'all' ? '' : _timelineFilter} entries yet. '
                        'Clinic notes appear here after each visit.',
                        style: Type.footnote(context.p),
                      ),
                    )
                  else
                    for (final e in entries) _TimelineCard(entry: e, pet: pet),

                  const SizedBox(height: T.s20),
                  Text('Documents', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  if (pet.docs.isEmpty)
                    SoftCard(
                      child: Text(
                        'No documents yet. Vaccination certificates and health plans appear here after your visit.',
                        style: Type.footnote(context.p),
                      ),
                    )
                  else
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < pet.docs.length; i++) ...[
                            if (i > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 54),
                                child: Divider(height: 1, color: p.divider),
                              ),
                            RowTile(
                              title: pet.docs[i].name,
                              subtitle:
                                  '${pet.docs[i].kind} · ${shortDate(pet.docs[i].date)} · ${pet.docs[i].size} KB',
                              leadingPath: Ic.doc,
                              onTap: () => _openDoc(context, pet.docs[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDoc(BuildContext context, PetDoc d) {
    showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
            const SizedBox(height: T.s16),
            _DocPreview(doc: d),
            const SizedBox(height: T.s20),
            PrimaryButton(
              label: 'Download',
              icon: Ic.download,
              onPressed: () {
                dismissSheet(context);
                ScaffoldlessNotice.show(context, '${d.name} saved to Files.');
              },
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Close',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Document preview tile: the real scanned image when the doc has one,
/// tappable to a full-screen zoom viewer; otherwise the placeholder.
class _DocPreview extends StatelessWidget {
  const _DocPreview({required this.doc});

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
                const SizedBox(height: 10),
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

class _VitalsInline extends StatelessWidget {
  const _VitalsInline({required this.vitals});
  final List<Vital> vitals;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final shown = vitals;
    return Row(
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 34,
              color: p.isDark
                  ? T.card.withValues(alpha: 0.18)
                  : T.taupe.withValues(alpha: 0.3),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ic.svg(Ic.byName(shown[i].icon), color: p.accent, size: 16),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${shown[i].value} ${shown[i].unit}'.trim(),
                    style: Type.footnoteEmph(p).copyWith(fontSize: 14),
                  ),
                ),
                Text(
                  shown[i].label,
                  style: Type.caption(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({required this.pet});
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
            const SizedBox(height: 10),
            Text(
              v.value.trim() == '—' || v.value.trim().isEmpty
                  ? 'No reading yet — the clinic records this at ${pet.name}\u2019s first visit.'
                  : 'Recorded for ${pet.name} at the last clinic visit. Your vet updates these after each '
                        'examination.',
              style: Type.footnote(context.p),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: T.s20),
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

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entry, required this.pet});
  final TimelineEntry entry;
  final Pet pet;

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
                      Text(shortDate(entry.date), style: Type.caption(p)),
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
            const SizedBox(height: T.s20),
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

/// Small shared notice used across profile/document sheets.
class ScaffoldlessNotice {
  static void show(BuildContext context, String message) {
    showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
            const SizedBox(height: T.s20),
            PrimaryButton(label: 'OK', onPressed: () => dismissSheet(context)),
          ],
        ),
      ),
    );
  }
}
