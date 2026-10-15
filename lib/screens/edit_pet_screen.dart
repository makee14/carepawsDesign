import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../app.dart';
import '../data/models.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../services/photo_store.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import 'photo_crop_screen.dart';

/// Edit an existing pet: portrait, identity, breed, sex, weight and allergies.
///
/// Timeline entries and documents belong to the clinic record, so they are
/// carried over untouched rather than edited here.
class EditPetScreen extends StatefulWidget {
  const EditPetScreen({super.key, required this.petId});

  final String petId;

  @override
  State<EditPetScreen> createState() => _EditPetScreenState();
}

class _EditPetScreenState extends State<EditPetScreen> {
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _length = TextEditingController();
  final _allergies = TextEditingController();
  String? _sex;
  DateTime? _birthDate;
  Uint8List? _photo;
  bool _picking = false;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    final pet = AppScope.of(context).pet(widget.petId);
    if (pet == null) return;
    _initialised = true;
    _name.text = pet.name;
    _breed.text = pet.breed;
    _weight.text = pet.weightKg.toStringAsFixed(1);
    _height.text = pet.heightCm?.toStringAsFixed(1) ?? '';
    _length.text = pet.lengthCm?.toStringAsFixed(1) ?? '';
    _allergies.text = pet.allergies.join(', ');
    _sex = pet.sex;
    _birthDate = pet.birthDate;
    _photo = pet.photo;
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _weight.dispose();
    _height.dispose();
    _length.dispose();
    _allergies.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final bytes = await PhotoStore.pick(source);
      if (bytes == null || !mounted) return;
      // Crop/edit step before the photo becomes the portrait.
      final cropped = await Navigator.of(
        context,
      ).push<Uint8List?>(appRouteT<Uint8List?>(PhotoCropScreen(bytes: bytes)));
      if (cropped == null || !mounted) return;
      setState(() => _photo = cropped);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Weight must be a real number in a plausible pet range. The old code
  /// silently fell back to the previous weight on bad input, so typing "4.."
  /// or "abc" looked like the field was stuck. Now it shows why.
  double? get _parsedWeight {
    final w = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (w == null || !w.isFinite) return null;
    if (w < 0.2 || w > 120) return null;
    return w;
  }

  String? get _weightError {
    if (_weight.text.trim().isEmpty) {
      return 'Enter a weight so the clinic can dose correctly.';
    }
    if (_parsedWeight == null) {
      return 'Use a number like 4.6 — between 0.2 and 120 kg.';
    }
    return null;
  }

  /// True when any field differs from the saved pet — what the discard
  /// confirm protects. Controllers are seeded from the pet, so untouched
  /// fields compare equal; `_birthDate`/`_photo` only diverge once the user
  /// picks something (photo removal sets an empty sentinel, never null).
  /// Height/length compare against the seeded text ('' when never recorded).
  bool _dirtyFor(Pet pet) =>
      _name.text != pet.name ||
      _breed.text != pet.breed ||
      _sex != pet.sex ||
      (_birthDate != null && _birthDate != pet.birthDate) ||
      _weight.text != pet.weightKg.toStringAsFixed(1) ||
      _height.text != (pet.heightCm?.toStringAsFixed(1) ?? '') ||
      _length.text != (pet.lengthCm?.toStringAsFixed(1) ?? '') ||
      _allergies.text != pet.allergies.join(', ') ||
      _photo != pet.photo;

  /// Nav-bar back / system back with unsaved edits: leave only on confirm.
  /// Saving pops directly (a direct pop bypasses PopScope), so this is only
  /// the abandon path.
  Future<void> _exit(Pet pet) async {
    if (await confirmDiscardIfDirty(context, isDirty: _dirtyFor(pet))) {
      if (mounted) dismissSheet(context);
    }
  }

  /// Optional measurement: empty means "not recorded" (null); a non-empty
  /// value must be a plausible number or the field explains why.
  double? _parseMeasure(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || !v.isFinite || v < 1 || v > 300) return null;
    return v;
  }

  String? _measureError(TextEditingController c) {
    if (c.text.trim().isEmpty) return null;
    if (_parseMeasure(c) == null) {
      return 'Use a number like 25 — between 1 and 300 cm, or leave empty.';
    }
    return null;
  }

  Future<void> _pickBirthDate(DateTime current) async {
    final now = DateTime.now();
    final picked = await showDatePickerSheet(
      context,
      initial: _birthDate ?? current,
      minimum: DateTime(now.year - 30),
      maximum: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _save(Pet pet) {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    final w = _parsedWeight;
    if (w == null) return;
    final allergies = _allergies.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Keep the weight vital in step with the number in the form.
    final vitals = pet.vitals
        .map(
          (v) => v.label == 'Weight'
              ? Vital(
                  label: v.label,
                  value: w.toStringAsFixed(1),
                  unit: v.unit,
                  icon: v.icon,
                )
              : v,
        )
        .toList();

    AppScope.read(context).updatePet(
      Pet(
        id: pet.id,
        name: n,
        species: pet.species,
        breed: _breed.text.trim().isEmpty ? pet.breed : _breed.text.trim(),
        sex: _sex ?? pet.sex,
        birthDate: _birthDate ?? pet.birthDate,
        weightKg: w,
        heightCm: _parseMeasure(_height),
        lengthCm: _parseMeasure(_length),
        color: pet.color,
        microchip: pet.microchip,
        allergies: allergies,
        vitals: vitals,
        timeline: pet.timeline,
        docs: pet.docs,
        photo: _photo,
      ),
    );
    successHaptic();
    dismissSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    final pet = store.pet(widget.petId);

    if (pet == null) {
      return CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: const DetailNavBar(title: 'Edit pet'),
        child: EmptyState(
          icon: Ic.paw,
          title: 'Pet not found',
          body: 'This pet is no longer on the account.',
        ),
      );
    }

    final canSave =
        _name.text.trim().isNotEmpty &&
        _parsedWeight != null &&
        _measureError(_height) == null &&
        _measureError(_length) == null;
    final preview = _photo ?? pet.photo;
    final birthDate = _birthDate ?? pet.birthDate;

    // Android system back honours the same dirty guard as the nav-bar back.
    return PopScope(
      canPop: !_dirtyFor(pet),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _exit(pet);
      },
      child: CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: DetailNavBar(
          title: 'Edit pet',
          onBack: () => _exit(pet),
        ),
        child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  // ---------------------------------------------------- photo
                  Center(
                    child: Column(
                      children: [
                        SizedBox.square(
                          dimension: 132,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(T.rCard),
                            child: preview != null && preview.isNotEmpty
                                ? Image.memory(
                                    preview,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  )
                                : PetArt(
                                    seed: pet.id.hashCode.abs() % 4,
                                    species: pet.species,
                                    iconSize: 76,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Wrap, not a Row: at AX5 the pills don't fit side
                        // by side — wrapping keeps every action reachable
                        // instead of overflowing off the edge.
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _PhotoAction(
                              icon: Ic.camera,
                              label: 'Take photo',
                              onTap: _picking
                                  ? null
                                  : () => _pick(ImageSource.camera),
                            ),
                            _PhotoAction(
                              icon: Ic.image,
                              label: 'Choose photo',
                              onTap: _picking
                                  ? null
                                  : () => _pick(ImageSource.gallery),
                            ),
                            if (preview != null && preview.isNotEmpty)
                              _PhotoAction(
                                icon: Ic.trash,
                                label: 'Remove photo',
                                onTap: _picking
                                    ? null
                                    : () =>
                                          setState(() => _photo = Uint8List(0)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s24),

                  // ---------------------------------------------------- fields
                  _Labeled(
                    label: 'Name',
                    child: CupertinoTextField(
                      controller: _name,
                      onChanged: (_) => setState(() {}),
                      placeholder: pet.name,
                      textCapitalization: TextCapitalization.words,
                      padding: const EdgeInsets.all(14),
                      cursorColor: p.primaryFill,
                      decoration: _dec(p),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Labeled(
                    label: 'Breed',
                    hint: 'Type any breed',
                    child: CupertinoTextField(
                      controller: _breed,
                      placeholder: pet.breed,
                      textCapitalization: TextCapitalization.words,
                      padding: const EdgeInsets.all(14),
                      cursorColor: p.primaryFill,
                      decoration: _dec(p),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Labeled(
                    label: 'Birthdate',
                    hint: _ageLabel(birthDate),
                    child: PressScale(
                      onTap: () => _pickBirthDate(pet.birthDate),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: _dec(p),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${birthDate.month}/${birthDate.day}/${birthDate.year}',
                                style: Type.body(p),
                              ),
                            ),
                            Ic.svg(
                              Ic.calendar,
                              color: p.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Labeled(
                    label: 'Sex',
                    child: _Segmented(
                      value: _sex ?? pet.sex,
                      options: const ['Male', 'Female'],
                      onChanged: (v) => setState(() => _sex = v),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Labeled(
                    label: 'Weight (kg)',
                    hint: '0.2 – 120 kg',
                    child: CupertinoTextField(
                      controller: _weight,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      placeholder: pet.weightKg.toStringAsFixed(1),
                      padding: const EdgeInsets.all(14),
                      cursorColor: p.primaryFill,
                      decoration: _dec(p).copyWith(
                        border: Border.all(
                          color: _weightError == null
                              ? p.divider
                              : p.destructive,
                        ),
                      ),
                    ),
                  ),
                  if (_weightError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _weightError!,
                      style: Type.footnote(p).copyWith(color: p.destructive),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _Labeled(
                    label: 'Height (cm)',
                    hint: 'Optional — at the shoulder',
                    child: CupertinoTextField(
                      controller: _height,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      padding: const EdgeInsets.all(14),
                      cursorColor: p.primaryFill,
                      decoration: _dec(p).copyWith(
                        border: Border.all(
                          color: _measureError(_height) == null
                              ? p.divider
                              : p.destructive,
                        ),
                      ),
                    ),
                  ),
                  if (_measureError(_height) != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _measureError(_height)!,
                      style: Type.footnote(p).copyWith(color: p.destructive),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _Labeled(
                    label: 'Length (cm)',
                    hint: 'Optional — nose to tail base',
                    child: CupertinoTextField(
                      controller: _length,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      padding: const EdgeInsets.all(14),
                      cursorColor: p.primaryFill,
                      decoration: _dec(p).copyWith(
                        border: Border.all(
                          color: _measureError(_length) == null
                              ? p.divider
                              : p.destructive,
                        ),
                      ),
                    ),
                  ),
                  if (_measureError(_length) != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _measureError(_length)!,
                      style: Type.footnote(p).copyWith(color: p.destructive),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _Labeled(
                    label: 'Allergies',
                    hint: 'Separate with commas',
                    child: CupertinoTextField(
                      controller: _allergies,
                      placeholder: 'None known',
                      padding: const EdgeInsets.all(14),
                      cursorColor: p.primaryFill,
                      decoration: _dec(p),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vitals, visits and documents belong to the clinic record and are '
                    'not changed here.',
                    style: Type.footnote(p).copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: 'Save changes',
                icon: Ic.check,
                onPressed: canSave ? () => _save(pet) : null,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  BoxDecoration _dec(AppPalette p) => BoxDecoration(
    color: p.surface,
    borderRadius: BorderRadius.circular(T.rCard),
    border: Border.all(color: p.divider),
  );
}

String _ageLabel(DateTime birth) {
  final now = DateTime.now();
  int y = now.year - birth.year;
  int m = now.month - birth.month;
  if (now.day < birth.day) m--;
  if (m < 0) {
    y--;
    m += 12;
  }
  if (y <= 0) return '$m mo old';
  return '$y yr old';
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap, not Row: at very large text scales the hint drops below the
        // label instead of squeezing it into a mid-word wrap (AX5). The
        // SizedBox keeps the full width so spaceBetween still pushes the
        // hint right at 1x (a bare Wrap would shrink-wrap and jam them).
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(label, style: Type.footnoteEmph(p)),
              if (hint != null)
                Text(
                  hint!,
                  style: Type.caption(p).copyWith(color: p.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.4 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(T.rControl),
                border: Border.all(color: p.divider, width: 1.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Ic.svg(icon, color: p.accent, size: 16),
                  const SizedBox(width: 7),
                  // Flexible so an overlong label wraps instead of overflowing
                  // the row at very large text scales.
                  Flexible(child: Text(label, style: Type.footnoteEmph(p))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Row(
      children: [
        for (final o in options) ...[
          Expanded(
            child: PressScale(
              onTap: () => onChanged(o),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: o == value ? p.accent : p.surface,
                  borderRadius: BorderRadius.circular(T.rControl),
                  border: Border.all(
                    color: o == value ? p.accent : p.divider,
                    width: 1.4,
                  ),
                ),
                child: Text(
                  o,
                  style: Type.footnoteEmph(p)
                      .copyWith(color: o == value ? p.onPrimaryFill : p.text),
                ),
              ),
            ),
          ),
          if (o != options.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}
