import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

import '../app.dart';
import '../data/clinic.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../design/icons.dart';
import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../services/ai_service.dart';
import '../state/app_store.dart';
import '../widgets/ai_unavailable.dart';
import '../widgets/common.dart';
import 'add_pet_screen.dart';
import 'appointments/book_flow.dart';
import 'chat_thread_screen.dart';
import 'profile/settings_screens.dart';
import 'triage/health_result_sheet.dart';

enum TriageEntry { home, aiChat, booking }

/// One question on its own screen. `{pet}` in a title is replaced with the
/// step-0-selected pet's name.
class _Question {
  const _Question({
    required this.id,
    required this.title,
    required this.topic,
    required this.options,
  });
  final String id;
  final String title;
  final String topic;
  final List<String> options;
}

const _questions = [
  _Question(
    id: 'concern',
    title: 'What\u2019s the main concern?',
    topic: 'Concern',
    options: [
      'Eating or drinking',
      'Energy or behavior',
      'Skin, coat, or ears',
      'Vomiting or diarrhea',
      'Breathing or coughing',
      'Limping or pain',
      'Something else',
    ],
  ),
  _Question(
    id: 'duration',
    title: 'How long has this been going on?',
    topic: 'Duration',
    options: [
      'Started today',
      'A few days',
      'About a week',
      'Longer than a week',
    ],
  ),
  _Question(
    id: 'overall',
    title: 'How is {pet} doing overall?',
    topic: 'Overall',
    options: [
      'Normal — eating and playing',
      'A bit quieter than usual',
      'Clearly unwell — low energy',
      'Very unwell — barely eating or moving',
    ],
  ),
  _Question(
    id: 'warnings',
    title: 'Any of these warning signs?',
    topic: 'Warning signs',
    options: [
      'None of these',
      'Vomiting',
      'Diarrhea',
      'Not eating',
      'Trouble breathing',
      'Bleeding or injury',
    ],
  ),
];

/// Minimal AI Health Check. Three entry points (Home quick action, the
/// CarePaws AI thread, Book step 2) all land here.
///
/// Step 0 is pet selection and it is required — the check cannot start
/// without a pet, and the step-0 petId is authoritative for everything
/// downstream (name, AI call, result, handoff). The old AI-detects-the-pet
/// fallback produced the wrong-pet-name bug and is gone.
class TriageScreen extends StatefulWidget {
  const TriageScreen({
    super.key,
    this.entry = TriageEntry.home,
    this.preselectedPetId,
    this.onComplete,
  });

  final TriageEntry entry;
  final String? preselectedPetId;

  /// When provided (the booking flow), the raw triage result is returned
  /// instead of pushing a result screen. The check stays optional: backing
  /// out returns no result and the booking simply continues without it.
  final void Function(TriageResult? result)? onComplete;

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  /// 0 = pet selection, 1..N = questions, N+1 = photo (optional).
  int _step = 0;
  String? _petId;
  final Map<String, String> _answers = {};
  Uint8List? _photo;
  String? _photoMime;
  bool _picking = false;
  bool _busy = false;

  /// Set when a request fails after the flow already started — the failure
  /// surfaces inline so it is never a dead end.
  AiFailure? _aiFailure;

  HealthCheckResult? _result;

  /// The raw AI outcome, kept for the booking onComplete contract and the
  /// clinic handoff.
  TriageResult? _triage;

  /// Contact-vet decision: null = undecided, true = sent, false = declined.
  bool? _sent;

  int get _stepCount => 1 + _questions.length + 1;

  @override
  void initState() {
    super.initState();
    _petId = widget.preselectedPetId;
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Any progress in the flow is a draft worth protecting. The result view
  /// holds none — the answers were submitted to get there.
  bool get _isDraft =>
      _result == null && (_step > 0 || _answers.isNotEmpty || _photo != null);

  /// Nav-bar back / system back: step back inside the flow; confirm only
  /// when leaving the flow entirely with a draft. The nav bar keeps its
  /// default maybePop, which honours the PopScope below.
  Future<void> _exit() async {
    if (await confirmDiscardIfDirty(
      context,
      isDirty: _isDraft,
      title: 'Discard health check?',
      message: 'Your answers will be lost.',
    )) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _onBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      _exit();
    }
  }

  void _onContinue(AppStore store) {
    if (_step == _stepCount - 1) {
      _submit();
    } else {
      setState(() => _step++);
    }
  }

  bool _canContinue(AppStore store) {
    if (_step == 0) return _petId != null;
    if (_step <= _questions.length) {
      return _answers[_questions[_step - 1].id] != null;
    }
    // Photo step: the photo is optional, but without a live model the
    // request would only fail — the card above explains why instead.
    return !_busy && store.ai.isLive;
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _photoMime = picked.mimeType ?? 'image/jpeg';
      });
    } catch (_) {
      // No camera / gallery available (desktop, simulator without photos).
      // Never a dead end: the photo is optional anyway.
      if (!mounted) return;
      await showPopup<void>(
        context,
        centered: true,
        barrierDismissible: false,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Photos unavailable here'),
          content: const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'This device cannot open the camera or photo library right now. '
              'You can skip this step — the health check works the same without a photo.',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => dismissSheet(ctx),
              child: const Text('Skip photo'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  String _transcript(Pet pet) {
    final lines = <String>[
      'Health check answers for ${pet.name} (${pet.breed}):',
    ];
    for (final q in _questions) {
      final title = q.title.replaceAll('{pet}', pet.name);
      lines.add('- $title ${_answers[q.id]}');
    }
    return lines.join('\n');
  }

  Future<void> _submit() async {
    final store = AppScope.read(context);
    final pet = store.pet(_petId ?? '');
    if (pet == null || _busy) return;
    setState(() {
      _busy = true;
      _aiFailure = null;
    });
    try {
      final triage = await store.ai.triage(
        petName: pet.name,
        species: pet.breed,
        text: _transcript(pet),
        photo: _photo,
        photoMime: _photoMime,
        ownerFirstName: store.ownerFirstName,
      );
      final answers = [
        for (final q in _questions)
          HealthAnswer(
            questionId: q.id,
            question: q.title.replaceAll('{pet}', pet.name),
            answer: _answers[q.id]!,
          ),
      ];
      // The step-0 petId is authoritative — threaded in, never re-derived.
      final result = HealthCheckResult.fromTriage(
        id: 'hc${store.now.microsecondsSinceEpoch}',
        petId: pet.id,
        triage: triage,
        answers: answers,
        createdAt: store.now,
      );
      store.recordHealthResult(result);
      if (!mounted) return;
      setState(() => _busy = false);
      // Booking entry: return the raw result; the caller's onComplete pops.
      if (widget.onComplete != null) {
        widget.onComplete!(triage);
        return;
      }
      setState(() {
        _result = result;
        _triage = triage;
        _sent = null;
      });
      successHaptic();
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _aiFailure = e.failure;
      });
    }
  }

  void _sendToClinic(AppStore store, Pet pet, TriageResult triage) {
    store.handOffToClinic(pet: pet, result: triage);
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;

    // Android system back honours the same step-aware guard as the nav bar.
    return PopScope(
      canPop: !_isDraft,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_step > 0 && _result == null) {
          setState(() => _step--);
          return;
        }
        await _exit();
      },
      child: CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: DetailNavBar(title: 'AI Health Check', showBack: true),
        child: SafeArea(
          child: _result == null ? _flow(store) : _results(store),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ flow
  Widget _flow(AppStore store) {
    if (store.pets.isEmpty) return _noPets();
    // Bootstrap state (no key / unreachable / API error) and a request that
    // just failed both land here — one card, never a dead end.
    final failure =
        _aiFailure ??
        (store.ai.status == AiStatus.unavailable
            ? store.ai.failure ?? AiFailure.noKey
            : null);
    final showCard = failure != null && (_step == 0 || _step == _stepCount - 1);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (showCard) ...[
                AiUnavailableCard(
                  failure: failure,
                  onOpenSettings: () =>
                      Navigator.of(context)
                          .push(appRoute(const AiSettingsScreen())),
                  onBook: widget.onComplete == null
                      ? () =>
                            Navigator.of(context)
                                .push(appRoute(const BookFlow()))
                      : null,
                  onCall: () => callPhoneNumber(
                    context,
                    number: Clinic.phone,
                    name: Clinic.name,
                  ),
                ),
                const SizedBox(height: T.s16),
              ],
              _progress(),
              const SizedBox(height: T.s20),
              _stepBody(store),
            ],
          ),
        ),
        _bottomBar(store),
      ],
    );
  }

  Widget _noPets() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        EmptyState(
          icon: 'paw',
          title: 'No pets yet',
          body: 'The health check needs a pet to be about. Add one — it takes a minute.',
          actionLabel: 'Add your first pet',
          onAction: () =>
              Navigator.of(context).push(appRoute(const AddPetScreen())),
        ),
      ],
    );
  }

  Widget _progress() {
    final p = context.p;
    final reduce = reduceMotionOf(context);
    final topic = _step == 0
        ? 'Pet'
        : _step <= _questions.length
        ? _questions[_step - 1].topic
        : 'Photo';
    final frac = (_step + 1) / _stepCount;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 4,
            child: LayoutBuilder(
              builder: (ctx, c) => Stack(
                children: [
                  Container(color: T.taupe.withValues(alpha: 0.3)),
                  AnimatedContainer(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    width: c.maxWidth * frac,
                    color: T.orange,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Step ${_step + 1} of $_stepCount',
              style: Type.footnote(p).copyWith(color: p.textSecondary),
            ),
            const Spacer(),
            Text(
              topic,
              style: Type.footnote(p).copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepBody(AppStore store) {
    if (_step == 0) return _petStep(store);
    if (_step <= _questions.length) {
      return _questionStep(store, _questions[_step - 1]);
    }
    return _photoStep();
  }

  Widget _petStep(AppStore store) {
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Which pet is this check for?', style: Type.title2(p)),
        const SizedBox(height: T.s16),
        for (final pet in store.pets) ...[
          _petOption(pet),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _petOption(Pet pet) {
    final p = context.p;
    final selected = _petId == pet.id;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Check ${pet.name}',
      child: PressScale(
        onTap: () => setState(() => _petId = pet.id),
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? T.orange.withValues(alpha: 0.15) : p.surface,
            borderRadius: BorderRadius.circular(T.rControl),
            border: Border.all(
              color: selected ? T.orange : p.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              PetArt(
                seed: pet.id.hashCode.abs() % 4,
                species: pet.species,
                radius: 12,
                iconSize: 34,
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
                      style: Type.title1(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${pet.species.name[0].toUpperCase()}${pet.species.name.substring(1)} · ${pet.ageLabel}',
                      style: Type.footnote(p).copyWith(color: p.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? T.orange : const Color(0x00000000),
                  border: Border.all(
                    color: selected ? T.orange : p.textSecondary,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Ic.svg(Ic.check, color: T.card, size: 14, stroke: 3)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionStep(AppStore store, _Question q) {
    final p = context.p;
    final pet = store.pet(_petId ?? '');
    final title = q.title.replaceAll('{pet}', pet?.name ?? 'your pet');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Type.title2(p)),
        const SizedBox(height: T.s24),
        for (final opt in q.options) ...[
          _optionRow(q, opt),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _optionRow(_Question q, String opt) {
    final p = context.p;
    final selected = _answers[q.id] == opt;
    return Semantics(
      button: true,
      selected: selected,
      label: opt,
      child: PressScale(
        onTap: () => setState(() => _answers[q.id] = opt),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? T.orange.withValues(alpha: 0.15) : p.surface,
            borderRadius: BorderRadius.circular(T.rControl),
            border: Border.all(
              color: selected ? T.orange : p.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(child: Text(opt, style: Type.body(p))),
              if (selected) Ic.svg(Ic.check, color: T.orange, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoStep() {
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add a photo (optional)', style: Type.title2(p)),
        const SizedBox(height: 4),
        Text(
          'A clear photo helps the assessment. You can skip this step.',
          style: Type.footnote(p).copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: T.s16),
        if (_photo != null)
          _PhotoPreview(
            bytes: _photo!,
            onRemove: () => setState(() => _photo = null),
          )
        else
          Row(
            children: [
              Expanded(
                child: _PhotoPickTile(
                  icon: Ic.camera,
                  label: 'Take photo',
                  onTap: _picking ? null : () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PhotoPickTile(
                  icon: Ic.image,
                  label: 'Choose photo',
                  onTap: _picking ? null : () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _bottomBar(AppStore store) {
    final p = context.p;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: TabBarClearance.of(context)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_step == 0 && _petId == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Choose a pet to start the check',
                  style: Type.footnote(p).copyWith(color: p.textSecondary),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(label: 'Back', onPressed: _onBack),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: _step == _stepCount - 1
                        ? 'Run health check'
                        : 'Continue',
                    busy: _busy,
                    onPressed: _canContinue(store)
                        ? () => _onContinue(store)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- results
  Widget _results(AppStore store) {
    final result = _result!;
    final triage = _triage!;
    // The step-0 selection is authoritative — the header, the AI call and
    // the handoff all read this petId, never a re-derived one.
    final pet = store.pet(result.petId);
    final petName = pet?.name ?? 'your pet';
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        40 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        HealthCheckResultView(
          result: result,
          petName: petName,
          // Any emergency route leads with the call card; its chat button
          // stays as the secondary path inside the recommendation card.
          leading: triage.route == TriageRoute.emergency
              ? _emergencyCard(store, pet)
              : null,
          action: _resultAction(store, pet, triage),
          contactVet: _contactVet(store, pet, triage),
        ),
      ],
    );
  }

  /// Urgent outcomes keep the call CTA above the fold.
  Widget _emergencyCard(AppStore store, Pet? pet) {
    final p = context.p;
    final open = clinicOpenAt(store.now);
    final number = open ? Seed.clinicPhone : Seed.afterHoursPhone;
    final name = open ? Seed.clinicName : Seed.afterHoursName;
    return SoftCard(
      color: p.destructive,
      padding: const EdgeInsets.all(T.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Ic.svg(Ic.phone, color: p.onPrimaryFill, size: 20, stroke: 2.2),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  open ? 'Call the clinic now' : 'Call $name',
                  style: Type.headline(p).copyWith(color: p.onPrimaryFill),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            number,
            style: Type.title2(p)
                .copyWith(color: p.onPrimaryFill, letterSpacing: 0.4),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: open ? 'Call the clinic now' : 'Call $name',
            icon: Ic.phone,
            onPressed: () =>
                callPhoneNumber(context, number: number, name: name),
          ),
        ],
      ),
    );
  }

  Widget? _resultAction(AppStore store, Pet? pet, TriageResult triage) {
    switch (triage.route) {
      case TriageRoute.book:
        return PrimaryButton(
          label: 'Book appointment',
          icon: Ic.calendar,
          onPressed: () => Navigator.of(context)
              .push(appRoute(BookFlow(initialPetId: pet?.id, triage: triage))),
        );
      case TriageRoute.chat:
        return Column(
          children: [
            PrimaryButton(
              label: 'Chat clinic team about this',
              icon: Ic.send,
              onPressed: pet == null
                  ? null
                  : () => _handoff(context, pet, triage),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Book instead',
              icon: Ic.calendar,
              onPressed: () => Navigator.of(
                context,
              ).push(appRoute(BookFlow(initialPetId: pet?.id, triage: triage))),
            ),
          ],
        );
      case TriageRoute.homeCare:
        return Column(
          children: [
            PrimaryButton(
              label: 'Chat clinic team about this',
              icon: Ic.send,
              onPressed: pet == null
                  ? null
                  : () => _handoff(context, pet, triage),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Book anyway',
              icon: Ic.calendar,
              onPressed: () => Navigator.of(
                context,
              ).push(appRoute(BookFlow(initialPetId: pet?.id, triage: triage))),
            ),
          ],
        );
      case TriageRoute.emergency:
        // The urgent call card above carries the primary action; the chat
        // team stays reachable as a secondary path.
        return SecondaryButton(
          label: 'Chat clinic team about this',
          icon: Ic.chat,
          onPressed: pet == null ? null : () => _handoff(context, pet, triage),
        );
    }
  }

  /// "Contact vet": the row recommends whether to send, the user decides.
  /// Both paths land somewhere sensible — never a dead end.
  Widget _contactVet(AppStore store, Pet? pet, TriageResult triage) {
    final p = context.p;
    Widget line(String icon, String text) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(T.rControl),
        border: Border.all(color: p.divider),
      ),
      child: Row(
        children: [
          Ic.svg(icon, color: p.textSecondary, size: 16),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: Type.footnote(p))),
        ],
      ),
    );
    if (_sent == true) return line(Ic.check, 'Sent to the clinic team.');
    if (_sent == false) {
      return line(Ic.info, 'Kept private to this check.');
    }
    final recommend = _result!.urgency != Urgency.low;
    return Container(
      padding: const EdgeInsets.all(T.s16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(T.rCard),
        border: Border.all(color: p.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Ic.svg(Ic.info, color: p.textSecondary, size: 16),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  recommend
                      ? 'We recommend sending this to the clinic — the vet can review it before your visit.'
                      : 'No need to send this — but you can if you\u2019d like.',
                  style: Type.footnote(p),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Send to clinic',
                  onPressed: pet == null
                      ? null
                      : () => _sendToClinic(store, pet, triage),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  label: 'Don\u2019t send',
                  onPressed: () => setState(() => _sent = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared AI -> clinic handoff. No-ops safely when there is no pet yet.
Future<void> _handoff(
  BuildContext context,
  Pet? pet,
  TriageResult result,
) async {
  if (pet == null) return;
  AppScope.read(context).handOffToClinic(pet: pet, result: result);
  if (!context.mounted) return;
  await Navigator.of(context).pushReplacement(
    appRoute(ChatThreadScreen(threadId: 'th_clinic', openedWithPetId: pet.id)),
  );
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.bytes, required this.onRemove});
  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Attached photo of the pet',
      image: true,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(T.rCard),
            child: Image.memory(
              bytes,
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconTap(
              path: Ic.close,
              label: 'Remove photo',
              color: T.card,
              background: const Color(0xB21A1008),
              onPressed: onRemove,
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: StatusChip(
              label: 'Photo attached',
              icon: Ic.check,
              compact: true,
              fg: T.espresso,
              bg: T.cream.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPickTile extends StatelessWidget {
  const _PhotoPickTile({
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
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(T.rCard),
              border: Border.all(color: p.divider, width: 1.4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Ic.svg(icon, color: p.accent, size: 24),
                const SizedBox(height: 8),
                Text(label, style: Type.footnoteEmph(p)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
