import 'package:flutter/cupertino.dart';

import '../../app.dart'
    show
        DetailNavBar,
        LargeTitleBar,
        appRoute,
        dismissSheet,
        shortDate,
        showAppSheet;
import '../../data/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import '../../widgets/pet_record_cards.dart';
import 'medical_entry_screen.dart';

/// One searchable patient entry: the pet plus the customer it belongs to.
///
/// Local prototype: every pet lives on the account currently in the store,
/// so the customer name is the account's. The backend swap feeds the same
/// shape from the full customer roster — no vet-side model duplicates, ever
/// (the same rule the spec pins for `Pet`).
@immutable
class VetPatient {
  const VetPatient({required this.customerName, required this.pet});
  final String customerName;
  final Pet pet;
}

/// The vet's patient index, built from the shared models — presentational
/// only, never reaches into the store itself.
List<VetPatient> buildVetPatients(AppStore store) => [
  for (final p in store.pets) VetPatient(customerName: store.ownerName, pet: p),
];

/// Filters patients by customer or pet name — case-insensitive partial
/// match; an empty query returns everything.
List<VetPatient> filterVetPatients(List<VetPatient> entries, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return entries;
  return entries
      .where(
        (e) =>
            e.pet.name.toLowerCase().contains(q) ||
            e.customerName.toLowerCase().contains(q),
      )
      .toList();
}

/// PETS — customer + pet search, patient list, full history, medical write.
class VetPetsScreen extends StatefulWidget {
  const VetPetsScreen({super.key});

  @override
  State<VetPetsScreen> createState() => _VetPetsScreenState();
}

class _VetPetsScreenState extends State<VetPetsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(VetPatient patient) {
    Navigator.of(context)
        .push(appRoute(VetPetDetailScreen(petId: patient.pet.id)));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final entries = filterVetPatients(buildVetPatients(store), _search.text);
    final searching = _search.text.trim().isNotEmpty;

    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Pets'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, T.s12),
              // 44pt floor at 1x, scaled (clamped 1.6x) so large Dynamic Type
              // doesn't clip the field's text — same recipe as the chats tab.
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
          if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Ic.paw,
                title: searching ? 'No matching patients' : 'No patients yet',
                body: searching ? 'Try a different customer or pet name.' : 'Patients appear here once they are registered at the clinic.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, T.s12),
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: T.s12),
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  return _PatientRow(
                    key: ValueKey(entry.pet.id),
                    patient: entry,
                    onTap: () => _open(entry),
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

/// One patient row: pet avatar, pet name, customer + breed, pet code. The
/// whole card is the tap target — well above the 44pt minimum.
class _PatientRow extends StatelessWidget {
  const _PatientRow({super.key, required this.patient, required this.onTap});

  final VetPatient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final pet = patient.pet;
    // AX5: the row reflows vertically — name full-width, customer line and
    // pet code drop beneath — so nothing truncates into an ellipsis.
    final big = MediaQuery.textScalerOf(context).scale(1) > 1.0;
    final subtitle =
        '${patient.customerName} · ${pet.breed} · ${pet.sex}, ${pet.ageLabel}';

    return SoftCard(
      onTap: onTap,
      semanticLabel: '${pet.name}, patient of ${patient.customerName}',
      padding: const EdgeInsets.all(T.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PetAvatar(
            pet: pet,
            radius: 22,
            iconSize: 22,
            label: '${pet.name} portrait',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pet.name,
                  style: Type.headline(p),
                  maxLines: big ? null : 1,
                  overflow: big ? null : TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Type.footnote(p).copyWith(color: p.textSecondary),
                  maxLines: big ? null : 2,
                  overflow: big ? null : TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                StatusChip(label: pet.petCode, compact: true),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Ic.svg(Ic.chevronRight, color: p.textSecondary, size: 18, stroke: 2),
        ],
      ),
    );
  }
}

/// The patient's full record: banner, timeline (with audit), vitals,
/// documents, prescriptions — rendered through the SAME display components
/// the customer sees (lib/widgets/pet_record_cards.dart), plus the vet's
/// audit lines and the Add record flow.
class VetPetDetailScreen extends StatelessWidget {
  const VetPetDetailScreen({super.key, required this.petId});
  final String petId;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final pet = store.pet(petId);
    if (pet == null) {
      return CupertinoPageScaffold(
        backgroundColor: context.p.background,
        navigationBar: const DetailNavBar(title: 'Patient'),
        child: const SafeArea(
          child: EmptyState(
            icon: Ic.paw,
            title: 'Patient not found',
            body: 'This record is no longer on the account.',
          ),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: context.p.background,
      navigationBar: DetailNavBar(title: pet.name),
      child: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Banner(pet: pet)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(T.s16, T.s8, T.s16, 0),
                child: PrimaryButton(
                  label: 'Add record',
                  icon: Ic.plus,
                  onPressed: () => _addRecord(context, petId),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: T.s8)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, T.s16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SectionHeader(title: 'Timeline'),
                  if (pet.timeline.isEmpty)
                    const _SectionEmpty(text: 'No timeline entries yet.')
                  else
                    for (final e in pet.timeline)
                      TimelineCard(entry: e, pet: pet, showAudit: true),
                  const SectionHeader(title: 'Vitals'),
                  if (pet.vitals.isEmpty)
                    const _SectionEmpty(text: 'No vitals recorded yet.')
                  else
                    VitalsGrid(pet: pet),
                  const SectionHeader(title: 'Documents'),
                  if (pet.docs.isEmpty)
                    const _SectionEmpty(text: 'No documents attached yet.')
                  else
                    for (final d in pet.docs) _DocRow(doc: d),
                  const SectionHeader(title: 'Prescriptions'),
                  if (store.prescriptions.isEmpty)
                    const _SectionEmpty(text: 'No prescriptions issued yet.')
                  else
                    for (final rx in store.prescriptions)
                      _RxCard(rx: rx, store: store),
                  SizedBox(height: TabBarClearance.of(context)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The Add record sheet: four write flows, one per record kind. Each flow
  /// is its own form on [MedicalEntryScreen]; saving returns here — the
  /// workflow's own section — never blindly to Home.
  void _addRecord(BuildContext context, String petId) {
    showAppSheet(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(T.s16, 8, T.s16, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add record', style: Type.title1(context.p)),
            const SizedBox(height: 6),
            Text(
              'Every write is stamped with your staff id and the time.',
              style: Type.footnote(context.p),
            ),
            const SizedBox(height: T.s16),
            for (final kind in MedicalEntryKind.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  onTap: () {
                    dismissSheet(context);
                    Navigator.of(context).push(
                      appRoute(MedicalEntryScreen(petId: petId, kind: kind)),
                    );
                  },
                  semanticLabel: kind.label,
                  padding: const EdgeInsets.all(T.s16),
                  child: Row(
                    children: [
                      Ic.svg(
                        kind.icon,
                        color: context.p.accent,
                        size: 22,
                        stroke: 1.9,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(kind.label, style: Type.headline(context.p)),
                            const SizedBox(height: 2),
                            Text(
                              kind.blurb,
                              style: Type.footnote(context.p)
                                  .copyWith(color: context.p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Ic.svg(
                        Ic.chevronRight,
                        color: context.p.textSecondary,
                        size: 18,
                        stroke: 2,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Cancel',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Patient banner: avatar, name + pet code, breed/sex/age, weight.
class _Banner extends StatelessWidget {
  const _Banner({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.s16, T.s16, T.s16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PetAvatar(
            pet: pet,
            radius: 30,
            iconSize: 30,
            label: '${pet.name} portrait',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pet.name, style: Type.title1(p)),
                const SizedBox(height: 3),
                Text(
                  '${pet.breed} · ${pet.sex} · ${pet.ageLabel}',
                  style: Type.footnote(p).copyWith(color: p.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Wrap, not Row: at AX5 the chip grows and a Row would push
                // the weight text off the screen edge. Pixel-identical at 1x
                // (single line), reflows instead of clipping at 3.2x.
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(label: pet.petCode, compact: true),
                    Text(
                      '${pet.weightKg} kg',
                      style: Type.caption(p).copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Type.footnote(context.p)
            .copyWith(color: context.p.textSecondary),
      ),
    );
  }
}

/// One document row: name, kind + attached date, audit line when the
/// document was attached through the vet portal. Taps into the shared
/// document sheet.
class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc});
  final PetDoc doc;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: () => showDocSheet(context, doc),
        semanticLabel: '${doc.name}, ${doc.kind}',
        padding: const EdgeInsets.all(T.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Ic.svg(Ic.doc, color: p.accent, size: 22, stroke: 1.9),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(doc.name, style: Type.headline(p)),
                  const SizedBox(height: 3),
                  Text(
                    '${doc.kind} · ${shortDate(doc.date)}',
                    style: Type.footnote(p).copyWith(color: p.textSecondary),
                  ),
                  if (doc.staffId != null && doc.recordedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Recorded by ${doc.staffId} · ${shortDate(doc.recordedAt!)}',
                      style: Type.caption(p).copyWith(color: p.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Ic.svg(
              Ic.chevronRight,
              color: p.textSecondary,
              size: 18,
              stroke: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// One prescription card: product, active state, refills, issuer — and the
/// audit line (staff id + issued timestamp) for vet-issued scripts.
class _RxCard extends StatelessWidget {
  const _RxCard({required this.rx, required this.store});
  final Prescription rx;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final active = rx.activeAt(store.now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(T.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Ic.svg(Ic.shield, color: p.accent, size: 18, stroke: 1.9),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    store.productOf(rx.productId).name,
                    style: Type.headline(p),
                  ),
                ),
                StatusChip(
                  label: active ? 'Active' : 'Expired',
                  compact: true,
                  fg: active ? p.success : p.destructive,
                  bg: active
                      ? (p.isDark
                            ? p.success.withValues(alpha: 0.12)
                            : const Color(0xFFDDF2E3))
                      : const Color(0x1FDC2626),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Signed by ${rx.vetName} · ${rx.refills} refills · expires ${shortDate(rx.expires)}',
              style: Type.footnote(p).copyWith(color: p.textSecondary),
            ),
            if (rx.staffId != null) ...[
              const SizedBox(height: 2),
              Text(
                'Recorded by ${rx.staffId} · ${shortDate(rx.issued)}',
                style: Type.caption(p).copyWith(color: p.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
