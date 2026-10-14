import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';

/// Add a pet. Also the zero-pet empty state's next action.
class AddPetScreen extends StatefulWidget {
  const AddPetScreen({super.key, this.onAdded});

  final void Function(Pet pet)? onAdded;

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _name = TextEditingController();
  Species _species = Species.dog;
  final _breed = TextEditingController(text: 'Golden Retriever');
  final _customBreed = TextEditingController();
  bool _customBreedMode = false;
  String _sex = 'Male';
  final _weight = TextEditingController();
  DateTime? _birthDate;
  final _notes = TextEditingController();
  int _step = 0;
  final _allergy = TextEditingController();

  static const dogBreeds = [
    'Golden Retriever',
    'Labrador Retriever',
    'Mixed breed',
    'Shih Tzu',
    'Poodle',
  ];
  static const catBreeds = [
    'British Shorthair',
    'Domestic Shorthair',
    'Persian',
    'Siamese',
    'Maine Coon',
  ];

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _customBreed.dispose();
    _weight.dispose();
    _notes.dispose();
    _allergy.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  String get _breedValue {
    if (_customBreedMode) return _customBreed.text.trim();
    return _breed.text.trim();
  }

  double? get _parsedWeight {
    final w = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (w == null || !w.isFinite) return null;
    if (w < 0.2 || w > 120) return null;
    return w;
  }

  String? get _weightError {
    if (_weight.text.trim().isEmpty) return null;
    if (_parsedWeight == null) {
      return 'Use a number like 4.6 — between 0.2 and 120 kg.';
    }
    return null;
  }

  void _pickSpecies(Species s) {
    setState(() {
      _species = s;
      _customBreedMode = false;
      _customBreed.clear();
      _breed.text = s == Species.dog ? dogBreeds.first : catBreeds.first;
    });
  }

  void _save() {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    if (_weightError != null) return;
    final breed = _breedValue.isEmpty
        ? (_species == Species.dog ? 'Mixed breed' : 'Domestic Shorthair')
        : _breedValue;
    final w = _parsedWeight ?? (_species == Species.dog ? 12 : 4);
    final birth = _birthDate ?? store_();
    final pet = Pet(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      name: n,
      species: _species,
      breed: breed,
      sex: _sex,
      birthDate: birth,
      weightKg: w,
      color: _species == Species.dog
          ? const Color(0xFFE4843E)
          : const Color(0xFF9B8A76),
      microchip: 'Not registered yet',
      allergies: _allergy.text.trim().isEmpty
          ? const []
          : [_allergy.text.trim()],
      vitals: [
        Vital(
          label: 'Weight',
          value: w.toStringAsFixed(1),
          unit: 'kg',
          icon: 'scale',
        ),
        const Vital(label: 'Temperature', value: '—', unit: '', icon: 'fire'),
        const Vital(
          label: 'Heart rate',
          value: '—',
          unit: 'bpm',
          icon: 'heartPulse',
        ),
        const Vital(
          label: 'Next check',
          value: '—',
          unit: '',
          icon: 'calendar',
        ),
      ],
      timeline: [
        TimelineEntry(
          id: 'n${DateTime.now().microsecondsSinceEpoch}',
          petId: 'n',
          date: DateTime.now(),
          title: 'Profile created',
          detail:
              'Added to PetCare. Bring this pet to the next visit so the clinic can record vitals '
              'and complete the health record.',
          role: StaffRole.vetAssistant,
          staffName: Seed.assistant.name,
        ),
      ],
      docs: const [],
    );
    AppScope.read(context).addPet(pet);
    successHaptic();
    dismissSheet(context);
    widget.onAdded?.call(pet);
  }

  DateTime store_() {
    final now = AppScope.read(context).now;
    return DateTime(now.year - 2, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final breeds = _species == Species.dog ? dogBreeds : catBreeds;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: _step == 0 ? 'Add pet' : 'Almost done',
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  if (_step == 0) ...[
                    Center(
                      child: PetArt(
                        seed: _species == Species.dog ? 1 : 0,
                        radius: 60,
                        iconSize: 84,
                        label: 'Illustration of the pet you are adding',
                      ),
                    ),
                    const SizedBox(height: T.s24),
                    Text('Pet type', style: Type.headline(p)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SpeciesCard(
                            label: 'Dog',
                            icon: Ic.dog,
                            selected: _species == Species.dog,
                            onTap: () => _pickSpecies(Species.dog),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SpeciesCard(
                            label: 'Cat',
                            icon: Ic.cat,
                            selected: _species == Species.cat,
                            onTap: () => _pickSpecies(Species.cat),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: T.s20),
                    _LabeledField(
                      label: 'Name',
                      controller: _name,
                      hint: 'e.g. Pepper',
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: T.s16),
                    Text('Breed', style: Type.headline(p)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final b in breeds)
                          FilterPill(
                            label: b,
                            selected: !_customBreedMode && _breed.text == b,
                            onTap: () => setState(() {
                              _customBreedMode = false;
                              _breed.text = b;
                            }),
                          ),
                        FilterPill(
                          label: 'Other…',
                          selected: _customBreedMode,
                          onTap: () => setState(() => _customBreedMode = true),
                        ),
                      ],
                    ),
                    if (_customBreedMode) ...[
                      const SizedBox(height: 10),
                      _LabeledField(
                        label: 'Type the breed',
                        controller: _customBreed,
                        hint: _species == Species.dog
                            ? 'e.g. Aspin'
                            : 'e.g. Puspin',
                        onChanged: () => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: T.s20),
                    Text('Sex', style: Type.headline(p)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final s in ['Male', 'Female']) ...[
                          FilterPill(
                            label: s,
                            selected: _sex == s,
                            onTap: () => setState(() => _sex = s),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ] else ...[
                    Ic.svg(Ic.paw, color: p.accent, size: 40, stroke: 1.8),
                    const SizedBox(height: T.s12),
                    Text(
                      'One more detail',
                      style: Type.title1(p),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Weight lets the clinic dose correctly. Everything else can be filled in at the visit.',
                      style: Type.body(p).copyWith(color: p.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: T.s24),
                    _LabeledField(
                      label: 'Weight (kg)',
                      controller: _weight,
                      hint: _species == Species.dog ? 'e.g. 12.5' : 'e.g. 4.2',
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: () => setState(() {}),
                    ),
                    if (_weightError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _weightError!,
                        style: Type.footnote(p).copyWith(color: p.destructive),
                      ),
                    ],
                    const SizedBox(height: T.s16),
                    Text('Birthdate', style: Type.headline(p)),
                    const SizedBox(height: 10),
                    PressScale(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePickerSheet(
                          context,
                          initial:
                              _birthDate ??
                              DateTime(now.year - 2, now.month, now.day),
                          minimum: DateTime(now.year - 30),
                          maximum: now,
                        );
                        if (picked != null) setState(() => _birthDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(T.rCard),
                          border: Border.all(color: p.divider),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _birthDate == null
                                    ? 'About 2 years old (tap to change)'
                                    : '${_birthDate!.month}/${_birthDate!.day}/${_birthDate!.year} · ${_ageLabel(_birthDate!)}',
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
                    const SizedBox(height: T.s16),
                    _LabeledField(
                      label: 'Allergies (optional)',
                      controller: _allergy,
                      hint: 'e.g. Chicken, Grass',
                    ),
                    const SizedBox(height: T.s16),
                    _LabeledField(
                      label: 'Notes for the vet (optional)',
                      controller: _notes,
                      hint: 'Anything we should know',
                    ),
                    const SizedBox(height: T.s16),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Summary', style: Type.headline(p)),
                          const SizedBox(height: 8),
                          AmountRow(
                            label: 'Name',
                            value: _name.text.trim().isEmpty
                                ? '—'
                                : _name.text.trim(),
                          ),
                          AmountRow(
                            label: 'Type',
                            value: _species == Species.dog ? 'Dog' : 'Cat',
                          ),
                          AmountRow(
                            label: 'Breed',
                            value: _breedValue.isEmpty ? '—' : _breedValue,
                          ),
                          AmountRow(label: 'Sex', value: _sex),
                          AmountRow(
                            label: 'Weight',
                            value: _weight.text.trim().isEmpty
                                ? 'Add at the visit'
                                : '${_weight.text.trim()} kg',
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            StickyCta(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: _step == 0
                        ? 'Continue'
                        : 'Add ${_name.text.trim().isEmpty ? 'pet' : _name.text.trim()}',
                    icon: _step == 0 ? Ic.arrowRight : Ic.check,
                    onPressed: _step == 0
                        ? (_valid ? () => setState(() => _step = 1) : null)
                        : _save,
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Cancel',
                    onPressed: () => dismissSheet(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class _SpeciesCard extends StatelessWidget {
  const _SpeciesCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: SoftCard(
            padding: const EdgeInsets.symmetric(vertical: 20),
            borderColor: selected ? p.accent : null,
            color: selected ? T.amber.withValues(alpha: 0.14) : null,
            child: Column(
              children: [
                Ic.svg(
                  icon,
                  color: selected ? p.primaryFill : p.textSecondary,
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(label, style: Type.headline(p)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboard,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboard;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Type.headline(p)),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          onChanged: onChanged == null ? null : (_) => onChanged!(),
          keyboardType: keyboard,
          placeholder: hint,
          placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
          style: Type.body(p),
          padding: const EdgeInsets.all(14),
          cursorColor: p.primaryFill,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(color: p.divider),
          ),
        ),
      ],
    );
  }
}
