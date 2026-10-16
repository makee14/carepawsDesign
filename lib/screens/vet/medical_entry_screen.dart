import 'package:flutter/cupertino.dart';

import '../../app.dart' show DetailNavBar, shortDate;
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';

/// The four medical write flows. The vet picks a kind on the pet detail's
/// "Add record" sheet; each kind gets its own focused form. Every submit
/// goes through the [AppStore] write methods, which stamp the audit trail
/// (staff_id + timestamp) — the UI never touches audit fields.
enum MedicalEntryKind { timeline, vitals, prescription, document }

extension MedicalEntryKindX on MedicalEntryKind {
  String get label => switch (this) {
    MedicalEntryKind.timeline => 'Timeline entry',
    MedicalEntryKind.vitals => 'Vitals',
    MedicalEntryKind.prescription => 'Prescription',
    MedicalEntryKind.document => 'Document',
  };
  String get blurb => switch (this) {
    MedicalEntryKind.timeline => 'Visits, vaccines, procedures',
    MedicalEntryKind.vitals => 'Record a new reading',
    MedicalEntryKind.prescription => 'Issues into the customer\u2019s record',
    MedicalEntryKind.document => 'Attach a file reference',
  };
  String get icon => switch (this) {
    MedicalEntryKind.timeline => Ic.clipboard,
    MedicalEntryKind.vitals => Ic.heartPulse,
    MedicalEntryKind.prescription => Ic.shield,
    MedicalEntryKind.document => Ic.doc,
  };
}

class MedicalEntryScreen extends StatefulWidget {
  const MedicalEntryScreen({
    super.key,
    required this.petId,
    required this.kind,
  });
  final String petId;
  final MedicalEntryKind kind;

  @override
  State<MedicalEntryScreen> createState() => _MedicalEntryScreenState();
}

class _MedicalEntryScreenState extends State<MedicalEntryScreen> {
  // Timeline fields.
  final _title = TextEditingController();
  final _detail = TextEditingController();
  StaffRole _role = StaffRole.vet;
  DateTime? _date;
  String? _titleError;
  String? _detailError;

  // Vitals fields.
  int _vitalIdx = 0;
  final _value = TextEditingController();
  String? _valueError;

  // Prescription fields.
  late String _productId;
  int _refills = 2;
  int _validityIdx = 2; // 1 year

  // Document fields.
  final _docName = TextEditingController();
  int _docKindIdx = 0;
  String? _docNameError;

  static const _vitalOptions = [
    (label: 'Temperature', unit: '°C', icon: 'fire'),
    (label: 'Heart rate', unit: 'bpm', icon: 'heartPulse'),
    (label: 'Weight', unit: 'kg', icon: 'scale'),
  ];

  static const _docKinds = [
    'Lab result',
    'Vaccination record',
    'X-ray',
    'Note',
  ];

  static const _validities = [
    (label: '30 days', days: 30),
    (label: '90 days', days: 90),
    (label: '1 year', days: 365),
  ];

  @override
  void initState() {
    super.initState();
    _productId = Seed.products.firstWhere((p) => p.restricted).id;
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    _value.dispose();
    _docName.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _title.text.isNotEmpty ||
      _detail.text.isNotEmpty ||
      _value.text.isNotEmpty ||
      _docName.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final pet = store.pet(widget.petId);
    final p = context.p;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardIfDirty(context, isDirty: _isDirty)) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: DetailNavBar(title: widget.kind.label),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(T.s16, T.s16, T.s16, 0),
                  children: [
                    if (pet != null) ...[
                      Text(
                        'For ${pet.name} · ${pet.petCode}',
                        style: Type.footnote(p)
                            .copyWith(color: p.textSecondary),
                      ),
                      const SizedBox(height: T.s16),
                    ],
                    ..._formFields(context),
                    const SizedBox(height: T.s8),
                    Text(
                      'Saved with your staff id and the current time — the audit trail is automatic.',
                      style: Type.caption(p).copyWith(color: p.textSecondary),
                    ),
                    const SizedBox(height: T.s16),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(T.s16, 8, T.s16, T.s16),
                child: PrimaryButton(label: 'Save record', onPressed: _save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _formFields(BuildContext context) => switch (widget.kind) {
    MedicalEntryKind.timeline => _timelineFields(context),
    MedicalEntryKind.vitals => _vitalsFields(context),
    MedicalEntryKind.prescription => _prescriptionFields(context),
    MedicalEntryKind.document => _documentFields(context),
  };

  // ---------------------------------------------------------- timeline
  List<Widget> _timelineFields(BuildContext context) {
    final p = context.p;
    return [
      const _FieldLabel('Title'),
      _Field(
        controller: _title,
        placeholder: 'e.g. Annual vaccination',
        semanticsLabel: 'Entry title',
        error: _titleError,
        onChanged: (_) => setState(() {}),
      ),
      const _FieldLabel('Details'),
      _Field(
        controller: _detail,
        placeholder: 'What was done, findings, follow-up\u2026',
        semanticsLabel: 'Entry details',
        error: _detailError,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
      ),
      const _FieldLabel('Recorded by role'),
      SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<StaffRole>(
          groupValue: _role,
          onValueChanged: (v) => setState(() => _role = v ?? StaffRole.vet),
          children: {
            for (final r in StaffRole.values)
              r: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Text(r.short, style: Type.footnote(p)),
              ),
          },
        ),
      ),
      const SizedBox(height: T.s16),
      const _FieldLabel('Visit date'),
      SoftCard(
        onTap: _pickDate,
        semanticLabel:
            'Visit date, ${shortDate(_date ?? AppScope.read(context).now)}. Activate to change.',
        padding: const EdgeInsets.symmetric(horizontal: T.s16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                shortDate(_date ?? AppScope.read(context).now),
                style: Type.body(p),
              ),
            ),
            Ic.svg(Ic.calendar, color: p.accent, size: 20, stroke: 1.9),
          ],
        ),
      ),
    ];
  }

  Future<void> _pickDate() async {
    final store = AppScope.read(context);
    DateTime picked = _date ?? store.now;
    await showPopup<void>(
      context,
      builder: (ctx) => Container(
        height: 320,
        color: ctx.p.background,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: picked,
                  maximumDate: store.now,
                  onDateTimeChanged: (d) => picked = d,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(T.s16, 0, T.s16, T.s12),
                child: PrimaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    setState(() => _date = picked);
  }

  // ------------------------------------------------------------ vitals
  List<Widget> _vitalsFields(BuildContext context) {
    final p = context.p;
    final opt = _vitalOptions[_vitalIdx];
    return [
      const _FieldLabel('Reading'),
      SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _vitalIdx,
          onValueChanged: (v) => setState(() => _vitalIdx = v ?? 0),
          children: {
            for (var i = 0; i < _vitalOptions.length; i++)
              i: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Text(
                  _vitalOptions[i].label,
                  style: Type.footnote(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          },
        ),
      ),
      _FieldLabel('Value (${opt.unit})'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Field(
              controller: _value,
              placeholder: 'e.g. 38.6',
              semanticsLabel: 'Reading value',
              error: _valueError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(opt.unit, style: Type.body(p)),
          ),
        ],
      ),
    ];
  }

  // ------------------------------------------------------ prescription
  List<Widget> _prescriptionFields(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    return [
      const _FieldLabel('Product'),
      for (final product in Seed.products)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            onTap: () => setState(() => _productId = product.id),
            semanticLabel:
                '${product.name}${product.restricted ? ', prescription only' : ''}${_productId == product.id ? ', selected' : ''}',
            padding: const EdgeInsets.symmetric(
              horizontal: T.s16,
              vertical: 13,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        style: Type.body(p),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.restricted)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Prescription only',
                            style: Type.caption(p)
                                .copyWith(color: p.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _productId == product.id
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: _productId == product.id ? p.accent : p.textSecondary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      const _FieldLabel('Refills'),
      Row(
        children: [
          _StepperButton(
            icon: CupertinoIcons.minus,
            label: 'Fewer refills',
            onTap: _refills > 0 ? () => setState(() => _refills--) : null,
          ),
          Expanded(
            child: Text(
              '$_refills',
              style: Type.title2(p),
              textAlign: TextAlign.center,
              semanticsLabel: '$_refills refills',
            ),
          ),
          _StepperButton(
            icon: CupertinoIcons.plus,
            label: 'More refills',
            onTap: _refills < 12 ? () => setState(() => _refills++) : null,
          ),
        ],
      ),
      const _FieldLabel('Valid for'),
      SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _validityIdx,
          onValueChanged: (v) => setState(() => _validityIdx = v ?? 2),
          children: {
            for (var i = 0; i < _validities.length; i++)
              i: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Text(_validities[i].label, style: Type.footnote(p)),
              ),
          },
        ),
      ),
      const SizedBox(height: T.s16),
      Text(
        'Signed as ${store.auditStaffName}. The script appears in the customer\u2019s record and unlocks the product at checkout.',
        style: Type.footnote(p).copyWith(color: p.textSecondary),
      ),
    ];
  }

  // ---------------------------------------------------------- document
  List<Widget> _documentFields(BuildContext context) {
    final p = context.p;
    return [
      const _FieldLabel('Document name'),
      _Field(
        controller: _docName,
        placeholder: 'e.g. Blood panel 2026.pdf',
        semanticsLabel: 'Document name',
        error: _docNameError,
        onChanged: (_) => setState(() {}),
      ),
      const _FieldLabel('Kind'),
      SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _docKindIdx,
          onValueChanged: (v) => setState(() => _docKindIdx = v ?? 0),
          children: {
            for (var i = 0; i < _docKinds.length; i++)
              i: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Text(
                  _docKinds[i],
                  style: Type.footnote(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          },
        ),
      ),
      const SizedBox(height: T.s16),
      Text(
        'Attaching records the document reference in the pet\u2019s file — name, kind and date — with your staff id.',
        style: Type.footnote(p).copyWith(color: p.textSecondary),
      ),
    ];
  }

  // --------------------------------------------------------------- save
  void _save() {
    final store = AppScope.read(context);
    final ok = switch (widget.kind) {
      MedicalEntryKind.timeline => _saveTimeline(store),
      MedicalEntryKind.vitals => _saveVitals(store),
      MedicalEntryKind.prescription => _savePrescription(store),
      MedicalEntryKind.document => _saveDocument(store),
    };
    // Saved → back to the pet's own section, where the new record now sits.
    if (ok && mounted) Navigator.of(context).pop();
  }

  bool _saveTimeline(AppStore store) {
    var valid = true;
    if (_title.text.trim().isEmpty) {
      _titleError = 'Please enter a title.';
      valid = false;
    }
    if (_detail.text.trim().isEmpty) {
      _detailError = 'Please enter details.';
      valid = false;
    }
    setState(() {});
    if (!valid) return false;
    return store.addTimelineEntry(
      petId: widget.petId,
      title: _title.text.trim(),
      detail: _detail.text.trim(),
      role: _role,
      date: _date,
    );
  }

  bool _saveVitals(AppStore store) {
    if (_value.text.trim().isEmpty) {
      setState(() => _valueError = 'Please enter a reading.');
      return false;
    }
    final opt = _vitalOptions[_vitalIdx];
    return store.recordVitals(
      petId: widget.petId,
      vitals: [
        Vital(
          label: opt.label,
          value: _value.text.trim(),
          unit: opt.unit,
          icon: opt.icon,
        ),
      ],
    );
  }

  bool _savePrescription(AppStore store) => store.issuePrescription(
    productId: _productId,
    refills: _refills,
    validFor: Duration(days: _validities[_validityIdx].days),
  );

  bool _saveDocument(AppStore store) {
    if (_docName.text.trim().isEmpty) {
      setState(() => _docNameError = 'Please enter a document name.');
      return false;
    }
    return store.addDocument(
      petId: widget.petId,
      name: _docName.text.trim(),
      kind: _docKinds[_docKindIdx],
    );
  }
}

/// Section field label — 8pt-grid rhythm, caption weight like the rest of
/// the app's forms.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: T.s16, bottom: T.s8),
      child: Text(
        text,
        style: Type.footnote(context.p).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// One form field with an inline validation error — the app's standard
/// trust-boundary pattern (never silently accept bad input).
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.placeholder,
    required this.semanticsLabel,
    this.error,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });
  final TextEditingController controller;
  final String placeholder;
  final String semanticsLabel;
  final String? error;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: semanticsLabel,
          textField: true,
          // Keep the label on its own node: without this the node can merge
          // with a sibling and pick up a stray newline in the label.
          container: true,
          child: ExcludeSemantics(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              maxLines: maxLines,
              minLines: maxLines > 1 ? maxLines : null,
              keyboardType: keyboardType,
              onChanged: onChanged,
              padding: const EdgeInsets.symmetric(
                horizontal: T.s16,
                vertical: 13,
              ),
              style: Type.body(p),
              placeholderStyle: Type.body(p)
                  .copyWith(color: p.textSecondary.withValues(alpha: 0.7)),
              decoration: BoxDecoration(
                color: p.fieldBg,
                borderRadius: BorderRadius.circular(T.rControl),
                border: Border.all(
                  color: error == null ? p.divider : p.destructive,
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error!, style: Type.caption(p).copyWith(color: p.destructive)),
        ],
      ],
    );
  }
}

/// 44pt stepper button for the refills control.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.divider),
            ),
            child: Icon(
              icon,
              color: onTap == null ? p.textSecondary : p.accent,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
