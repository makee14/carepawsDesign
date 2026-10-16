import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import '../../widgets/pet_record_cards.dart';
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
                padding: const EdgeInsets.fromLTRB(T.s16, 12, T.s16, 28),
                children: [
                  // Banner: full-bleed photo (~210pt, the appointment card's
                  // language at a smaller size) with the glass name panel
                  // (deliberate G1 deviation — see contracts Deviation Log #2)
                  // floating over its lower portion. Structural overlap: the
                  // Column (spacer + panel) sizes the block in normal flow;
                  // the photo is a fixed-size slot painted behind. Nothing
                  // overflows, so no ancestor can clip the panel.
                  Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: Layout.heroHeight(context, 210),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(T.rCard),
                                child: PetAvatar(
                                  pet: pet,
                                  iconSize: 120,
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
                            height: Layout.heroHeight(context, 210) - 40,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(T.s16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _NameRow(
                                    name: pet.name,
                                    petCode: pet.petCode,
                                    onPetIdTap: () => _openIdCard(context, pet),
                                  ),
                                  const SizedBox(height: 12),
                                  // Weight / Age / Gender, always all three —
                                  // height/length stay editable in
                                  // EditPetScreen but don't show in the
                                  // banner.
                                  _MeasureStrip(pet: pet),
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

                  const SizedBox(height: T.s16),
                  Text('Details', style: Type.headline(p)),
                  const SizedBox(height: 8),
                  // Each fact appears exactly once on this screen: breed and
                  // sex live in the photo pill, weight in the banner strip —
                  // so Details keeps only Pet ID, Born and Allergies.
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        RowTile(
                          title: 'Pet ID',
                          subtitle: pet.petCode,
                          leadingPath: Ic.qr,
                          onTap: () => _openIdCard(context, pet),
                        ),
                        AmountRow(
                          label: 'Born',
                          value:
                              '${shortDate(pet.birthDate)}, ${pet.birthDate.year}',
                        ),
                        AmountRow(
                          label: 'Allergies',
                          value: pet.allergies.isEmpty
                              ? 'None known'
                              : pet.allergies.join(', '),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: T.s16),
                  Text('Vitals', style: Type.headline(p)),
                  const SizedBox(height: 8),
                  VitalsGrid(pet: pet),

                  const SizedBox(height: T.s16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Timeline', style: Type.headline(p)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
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
                    for (final e in entries) TimelineCard(entry: e, pet: pet),

                  const SizedBox(height: T.s16),
                  Text('Documents', style: Type.headline(p)),
                  const SizedBox(height: 8),
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
                              onTap: () => showDocSheet(context, pet.docs[i]),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: T.s20),
                  Text('Danger zone', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    borderColor: p.destructive.withValues(alpha: 0.3),
                    child: RowTile(
                      title: 'Delete ${pet.name}',
                      subtitle:
                          'Removes their profile, records and appointments',
                      leadingPath: Ic.trash,
                      destructive: true,
                      onTap: () => _deletePet(context, pet),
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

  /// Delete pet (S5): the confirm states the full blast radius, including how
  /// many upcoming appointments go with the pet. Active appointments are
  /// cancelled through the store's existing per-appointment path (no new
  /// backend semantics), then the pet is removed; the profile pops back to
  /// wherever it was opened from — never a dead end.
  Future<void> _deletePet(BuildContext context, Pet pet) async {
    final store = AppScope.read(context);
    final active = store.appointments
        .where((a) => a.petId == pet.id && a.status.isActive)
        .toList();
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${pet.name}?',
      message: active.isEmpty
          ? 'This permanently removes ${pet.name}\u2019s profile, vitals, '
                'timeline and documents. This cannot be undone.'
          : 'This permanently removes ${pet.name}\u2019s profile, vitals, '
                'timeline and documents, and cancels ${active.length == 1 ? 'their upcoming appointment' : 'their ${active.length} upcoming appointments'}. '
                'This cannot be undone.',
      confirmLabel: 'Delete ${pet.name}',
    );
    if (!ok || !context.mounted) return;
    for (final a in active) {
      store.cancelAppointment(a.id);
    }
    store.removePet(pet.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  /// Digital pet ID card: photo, name, the CP-XXXXXX code, breed, sex,
  /// birthdate and microchip. The microchip number lives here now that
  /// Details shows the Pet ID row instead. Compact by design: the whole
  /// card fits the sheet at 1x, and the sheet scrolls rather than
  /// overflowing at AX5.
  void _openIdCard(BuildContext context, Pet pet) {
    final p = context.p;
    showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(T.s16, 8, T.s16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pet ID', style: Type.title2(p)),
            const SizedBox(height: 12),
            SoftCard(
              borderColor: p.accent.withValues(alpha: 0.35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox.square(
                        dimension: 84,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: PetAvatar(
                            pet: pet,
                            iconSize: 52,
                            label: '${pet.name} portrait',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pet.name,
                              style: Type.title2(p),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            StatusChip(
                              label: pet.petCode,
                              icon: Ic.qr,
                              compact: true,
                              fg: p.accentText,
                              bg: p.accent.withValues(alpha: 0.12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${pet.breed} · ${pet.sex}',
                              style: Type.footnote(p)
                                  .copyWith(color: p.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Divider(height: 1, color: p.divider),
                  ),
                  AmountRow(
                    label: 'Born',
                    value: '${shortDate(pet.birthDate)}, ${pet.birthDate.year}',
                  ),
                  AmountRow(label: 'Microchip', value: pet.microchip),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Show this card at the clinic front desk.',
              style: Type.footnote(p).copyWith(color: p.textSecondary),
              textAlign: TextAlign.center,
            ),
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

/// Name + Pet ID chip. The chip opens the digital ID card — the same action
/// as the Pet ID row in Details, so the code is discoverable from the banner
/// too. Side by side at normal type sizes (the reference composition);
/// stacked when Dynamic Type goes huge, so the chip can never starve the
/// name to zero width — at AX5 that produced a 31px overflow and a 728px-tall
/// single-character name column.
class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.name,
    required this.petCode,
    required this.onPetIdTap,
  });
  final String name;
  final String petCode;
  final VoidCallback onPetIdTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final chip = Semantics(
      button: true,
      label: 'Pet ID $petCode. Show ID card.',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onPetIdTap,
          child: StatusChip(
            label: petCode,
            icon: Ic.qr,
            compact: true,
            fg: p.accentText,
            bg: p.accent.withValues(alpha: 0.12),
          ),
        ),
      ),
    );
    // Same "huge" threshold as Layout.heroHeight.
    final huge = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    if (huge) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: Type.title1(p),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          chip,
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: Type.title1(p),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        chip,
      ],
    );
  }
}

/// Banner stats: Weight, Age, Gender — always all three, in that order.
/// Typographic tiles (value + label, no icons): the icon set has no gender
/// glyph, and the HIG-native stat strip is typographic anyway. Values at
/// headline size so the strip holds its own against the title1 name; labels
/// are caption-size but full-strength text — the panel floats over an
/// arbitrary photo, where textSecondary can't promise 4.5:1 (same rule as
/// the appointment card body). Height/length stay on the Pet model and
/// editable in EditPetScreen; they just don't show in the banner.
class _MeasureStrip extends StatelessWidget {
  const _MeasureStrip({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final tiles = [
      ('${pet.weightKg} kg', 'Weight'),
      (pet.ageLabel, 'Age'),
      (pet.sex, 'Gender'),
    ];
    final dividerColor = p.isDark
        ? T.card.withValues(alpha: 0.18)
        : T.taupe.withValues(alpha: 0.3);
    Widget tile(int i) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Leading-aligned: each value sits under the name's leading edge
        // (first tile) or with even breathing room around the dividers.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(tiles[i].$1, style: Type.headline(p), maxLines: 1),
          ),
          const SizedBox(height: 2),
          Text(
            tiles[i].$2,
            style: Type.caption(p).copyWith(color: p.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(width: 1, height: 36, color: dividerColor),
    );
    return Row(children: [tile(0), divider(), tile(1), divider(), tile(2)]);
  }
}
