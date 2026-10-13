import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../services/ai_service.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import 'appointments/book_flow.dart';
import 'chat_thread_screen.dart';

enum TriageEntry { home, aiChat, booking }

/// Shared triage engine. Three entry points (Home quick action, the PetCare AI
/// thread, Book step 2) all land here.
class TriageScreen extends StatefulWidget {
  const TriageScreen({
    super.key,
    this.entry = TriageEntry.home,
    this.preselectedPetId,
    this.onComplete,
    this.showSkip = false,
  });

  final TriageEntry entry;
  final String? preselectedPetId;

  /// When provided (Book step 2), the result is returned instead of pushing a
  /// result screen, and "Skip triage" is offered.
  final void Function(TriageResult result)? onComplete;
  final bool showSkip;

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final _text = TextEditingController();
  String? _petId;
  TriageResult? _result;
  bool _busy = false;
  Uint8List? _photo;
  String? _photoMime;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _petId = widget.preselectedPetId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _petId ??= AppScope.of(context).pets.firstOrNull?.id;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
      // Never a dead end: the text-only path continues identically.
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Photos unavailable here'),
          content: const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'This device cannot open the camera or photo library right now. '
              'You can still submit a description — the health check works the same without a photo.',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => dismissSheet(ctx),
              child: const Text('Continue without photo'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    final store = AppScope.read(context);
    final pet = store.pet(_petId ?? '');
    if (pet == null) return;
    setState(() => _busy = true);
    final result = await store.ai.triage(
      petName: pet.name,
      species: pet.breed,
      text: _text.text.trim(),
      photo: _photo,
      photoMime: _photoMime,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
    successHaptic();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final result = _result;
    final pet = store.pet(_petId ?? '');

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: 'AI Health Check',
        showBack: true,
        actions: [
          if (store.ai.isDemo)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Center(child: DemoAiBadge(compact: true)),
            ),
        ],
      ),
      child: SafeArea(
        child: result == null
            ? _input(store, pet)
            : _resultView(store, result, pet),
      ),
    );
  }

  // ------------------------------------------------------------ input view
  Widget _input(AppStore store, Pet? pet) {
    final p = context.p;
    final canSubmit = !_busy && (_text.text.trim().isNotEmpty || _photo != null);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        120 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (store.ai.isDemo) ...[
          const DemoAiBadge(),
          const SizedBox(height: 10),
          Text(
            'Running the built-in responder. Add a GEMINI_API_KEY to run live model checks — '
            'every route below behaves identically either way.',
            style: Type.footnote(p),
          ),
          const SizedBox(height: T.s16),
        ],
        Text(
          'Tell us what is happening and we will sort it into the right next step.',
          style: Type.body(p).copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: T.s20),
        Text('Which pet?', style: Type.headline(p)),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: store.pets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => PetChip(
              pet: store.pets[i],
              selected: store.pets[i].id == _petId,
              onTap: () => setState(() => _petId = store.pets[i].id),
            ),
          ),
        ),
        const SizedBox(height: T.s20),
        Text('Describe the concern', style: Type.headline(p)),
        const SizedBox(height: 4),
        Text(
          'Symptoms, when it started, and anything that changed.',
          style: Type.footnote(p),
        ),
        const SizedBox(height: 10),
        CupertinoTextField(
          controller: _text,
          onChanged: (_) => setState(() {}),
          placeholder: 'e.g. Vomited twice this morning and will not eat breakfast',
          placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
          style: Type.body(p),
          minLines: 4,
          maxLines: 7,
          padding: const EdgeInsets.all(14),
          cursorColor: p.primaryFill,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(T.rCard),
            border: Border.all(color: p.divider),
          ),
        ),
        const SizedBox(height: T.s20),
        Text('Add a photo (optional)', style: Type.headline(p)),
        const SizedBox(height: 4),
        Text(
          'Sent to a vision-capable model. The text-only path works identically.',
          style: Type.footnote(p),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: T.s16),
        _Disclaimer(pet),
        const SizedBox(height: T.s24),
        PrimaryButton(
          label: 'Run health check',
          icon: Ic.sparkle,
          busy: _busy,
          onPressed: canSubmit ? _submit : null,
        ),
        if (widget.showSkip) ...[
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Skip triage',
            onPressed: _busy
                ? null
                : () {
                    final r = DemoAi.triage(
                      '',
                      petName: pet?.name ?? 'Your pet',
                      species: pet?.breed ?? 'dog',
                      hasPhoto: false,
                    );
                    if (widget.onComplete != null) {
                      dismissSheet(context);
                      widget.onComplete!(r);
                    } else {
                      setState(() => _result = r);
                    }
                  },
          ),
        ],
      ],
    );
  }

  // ----------------------------------------------------------- result view
  Widget _resultView(AppStore store, TriageResult result, Pet? pet) {
    // Emergency outcome: the call CTA is rendered first, above the fold.
    if (result.route == TriageRoute.emergency) {
      return EmergencyTriageView(result: result, pet: pet, entry: widget.entry);
    }
    void handoff() {
      if (pet == null) return;
      store.handOffToClinic(pet: pet, result: result);
      Navigator.of(context).pushReplacement(
        appRoute(
          ChatThreadScreen(
            threadId: 'th_clinic',
            openedWithPetId: pet.id,
            triageSummary: result.summary,
          ),
        ),
      );
    }

    return switch (result.route) {
      TriageRoute.book => BookTriageView(result: result, pet: pet, entry: widget.entry),
      TriageRoute.chat => ChatTriageView(result: result, pet: pet, handoff: handoff),
      TriageRoute.homeCare => HomeCareTriageView(result: result, pet: pet, entry: widget.entry),
      TriageRoute.emergency => EmergencyTriageView(result: result, pet: pet, entry: widget.entry),
    };
  }
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
            child: Image.memory(bytes, width: double.infinity, height: 190, fit: BoxFit.cover),
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
  const _PhotoPickTile({required this.icon, required this.label, required this.onTap});
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

class _Disclaimer extends StatelessWidget {
  const _Disclaimer(this.pet);
  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.fieldBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ic.svg(Ic.info, color: p.textSecondary, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              "PetCare AI gives guidance, not a diagnosis. A veterinarian has to examine "
              "${pet?.name ?? 'your pet'} in person to confirm anything.",
              style: Type.footnote(p),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- outcomes

class _OutcomeShell extends StatelessWidget {
  const _OutcomeShell({
    required this.child,
    required this.title,
    required this.icon,
    required this.tone,
    this.result,
  });

  final Widget child;
  final String title;
  final String icon;
  final Tone tone;
  final TriageResult? result;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 40 + MediaQuery.paddingOf(context).bottom),
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tone.bg,
                shape: BoxShape.circle,
              ),
              child: Center(child: Ic.svg(icon, color: tone.fg, size: 26, stroke: 2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Type.title2(p)),
                  const SizedBox(height: 4),
                  StatusChip(
                    label: result?.urgencyLabel ?? 'Reviewed',
                    compact: true,
                    icon: Ic.info,
                    fg: tone.fg,
                    bg: tone.bg,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: T.s16),
        child,
      ],
    );
  }
}

class Tone {
  const Tone(this.fg, this.bg);
  final Color fg;
  final Color bg;
  static const calm = Tone(Color(0xFF7A4A1B), Color(0x1AF4AE52));
  static const mid = Tone(Color(0xFFA8480F), Color(0x1FE4843E));
  static const alert = Tone(Color(0xFF9B1C1C), Color(0x1FDC2626));
  static const info = Tone(Color(0xFF1F5C33), Color(0x1FDDF2E3));
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items, required this.icon, required this.tone, this.heading});
  final List<String> items;
  final String icon;
  final Tone tone;
  final String? heading;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heading != null) ...[
          const SizedBox(height: T.s20),
          Text(heading!, style: Type.headline(p)),
          const SizedBox(height: 8),
        ],
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Ic.svg(icon, color: tone.fg, size: 16, stroke: 2.2),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item, style: Type.callout(p))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Outcome: book an appointment.
class BookTriageView extends StatelessWidget {
  const BookTriageView({super.key, required this.result, required this.pet, required this.entry});

  final TriageResult result;
  final Pet? pet;
  final TriageEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(
      children: [
        Expanded(
          child: _OutcomeShell(
            title: result.title,
            icon: Ic.calendar,
            tone: result.urgency == 2 ? Tone.alert : Tone.mid,
            result: result,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.summary, style: Type.body(p)),
                _Bullets(
                  items: result.bullets,
                  icon: Ic.check,
                  tone: Tone.info,
                  heading: 'What we noted',
                ),
                _Bullets(
                  items: result.redFlags,
                  icon: Ic.alert,
                  tone: Tone.alert,
                  heading: 'See a vet immediately if',
                ),
                if (result.nextStep != null) ...[
                  const SizedBox(height: T.s16),
                  _NoteBox(text: result.nextStep!, icon: Ic.arrowRight),
                ],
                const SizedBox(height: T.s16),
                _NotADiagnosis(),
              ],
            ),
          ),
        ),
        StickyCta(
          extra: pet == null
              ? null
              : SecondaryButton(
                  label: 'Chat clinic team about this',
                  icon: Ic.chat,
                  onPressed: () => _handoff(context, pet, result),
                ),
          child: PrimaryButton(
            label: 'Book appointment',
            icon: Ic.calendar,
            onPressed: () => Navigator.of(context).push(
              appRoute(
                BookFlow(
                  initialPetId: pet?.id,
                  triage: result,
                ),
              ),
            ),
          )),
      ],
    );
  }
}

/// Outcome: talk to the clinic team.
class ChatTriageView extends StatelessWidget {
  const ChatTriageView({
    super.key,
    required this.result,
    required this.pet,
    required this.handoff,
  });

  final TriageResult result;
  final Pet? pet;
  final VoidCallback handoff;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    return Column(
      children: [
        Expanded(
          child: _OutcomeShell(
            title: result.title,
            icon: Ic.chat,
            tone: Tone.mid,
            result: result,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.summary, style: Type.body(p)),
                _Bullets(
                  items: result.bullets,
                  icon: Ic.check,
                  tone: Tone.info,
                  heading: 'What we noted',
                ),
                _Bullets(
                  items: result.redFlags,
                  icon: Ic.alert,
                  tone: Tone.alert,
                  heading: 'See a vet immediately if',
                ),
                const SizedBox(height: T.s16),
                _NoteBox(
                  text: store.staffOnline()
                      ? 'The clinic team is online now and usually replies within 10 minutes.'
                      : store.offlineNote ?? 'The clinic team replies from 8:00 AM.',
                  icon: Ic.clock,
                ),
                const SizedBox(height: 12),
                _NoteBox(
                  text: '${pet?.name ?? 'Your pet'} and this summary travel with the message — no retyping.',
                  icon: Ic.info,
                ),
                const SizedBox(height: T.s16),
                _NotADiagnosis(),
              ],
            ),
          ),
        ),
        StickyCta(
          extra: SecondaryButton(
            label: 'Book instead',
            icon: Ic.calendar,
            onPressed: () => Navigator.of(context).push(
              appRoute(BookFlow(initialPetId: pet?.id, triage: result)),
            ),
          ),
          child: PrimaryButton(
            label: 'Chat clinic team about this',
            icon: Ic.send,
            onPressed: handoff,
          )),
      ],
    );
  }
}

/// Outcome: home care, with a red-flag list and a "Book anyway" secondary.
class HomeCareTriageView extends StatelessWidget {
  const HomeCareTriageView({super.key, required this.result, required this.pet, required this.entry});

  final TriageResult result;
  final Pet? pet;
  final TriageEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(
      children: [
        Expanded(
          child: _OutcomeShell(
            title: result.title,
            icon: Ic.heart,
            tone: Tone.calm,
            result: result,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.summary, style: Type.body(p)),
                _Bullets(
                  items: result.homeCare,
                  icon: Ic.checkCircle,
                  tone: Tone.info,
                  heading: 'Care instructions for the next 48 hours',
                ),
                _Bullets(
                  items: result.redFlags,
                  icon: Ic.alert,
                  tone: Tone.alert,
                  heading: 'Book straight away if you see',
                ),
                const SizedBox(height: T.s16),
                _NotADiagnosis(),
              ],
            ),
          ),
        ),
        StickyCta(
          extra: SecondaryButton(
            label: 'Book anyway',
            icon: Ic.calendar,
            onPressed: () => Navigator.of(context).push(
              appRoute(BookFlow(initialPetId: pet?.id, triage: result)),
            ),
          ),
          child: PrimaryButton(
            label: 'Chat clinic team about this',
            icon: Ic.send,
            onPressed: () {
              final store = AppScope.read(context);
              store.handOffToClinic(pet: pet!, result: result);
              Navigator.of(context).pushReplacement(
                appRoute(ChatThreadScreen(threadId: 'th_clinic', openedWithPetId: pet!.id)),
              );
            },
          )),
      ],
    );
  }
}

/// Emergency outcome. Primary "Call the clinic now" (tel:) sits above the fold;
/// after hours it becomes "Call {nearest emergency clinic}" with the number.
class EmergencyTriageView extends StatelessWidget {
  const EmergencyTriageView({
    super.key,
    required this.result,
    required this.pet,
    required this.entry,
  });

  final TriageResult result;
  final Pet? pet;
  final TriageEntry entry;

  static bool isOpen() => clinicOpenAt(DateTime.now());

  Future<void> _call(BuildContext context, String number, String name) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    var ok = false;
    try {
      ok = await launchUrl(uri) ||
          await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!context.mounted) return;
    // Desktop / simulators have no tel: handler — show the number instead of
    // a dead end.
    if (!ok) {
      await showAppSheet(
        context,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: Type.title2(context.p), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                number,
                style: Type.largeTitle(context.p).copyWith(color: context.p.accentText),
              ),
              const SizedBox(height: 6),
              Text(
                'Dial this number from your phone. PetCare will reopen at 8:00 AM.',
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

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final open = clinicOpenAt(store.now);
    final number = open ? Seed.clinicPhone : Seed.afterHoursPhone;
    final name = open ? Seed.clinicName : Seed.afterHoursName;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: p.destructive.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Ic.svg(Ic.alert, color: p.destructive, size: 26, stroke: 2.1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Possible emergency', style: Type.title2(p)),
                        const SizedBox(height: 4),
                        StatusChip(
                          label: open ? 'Clinic open now' : 'Clinic closed — after hours',
                          icon: Ic.clock,
                          compact: true,
                          fg: open ? p.success : p.destructive,
                          bg: open
                              ? const Color(0xFFDDF2E3)
                              : p.destructive.withValues(alpha: 0.12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: T.s16),
              Text(result.title, style: Type.title1(p)),
              const SizedBox(height: 8),
              Text(result.summary, style: Type.body(p)),
              // The call CTA is duplicated as an inline row so it is reachable
              // even before the sticky bar at the bottom of the scroll view.
              const SizedBox(height: T.s16),
              SoftCard(
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
                      style: Type.title2(p).copyWith(
                        color: p.onPrimaryFill,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      open
                          ? "Ask for the vet on duty. Keep ${pet?.name ?? 'your pet'} quiet and warm on the way."
                          : 'This hospital is open 24 hours. Go now — do not wait for PetCare to reopen.',
                      style: Type.footnote(p).copyWith(color: p.onPrimaryFill.withValues(alpha: 0.92)),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: open ? 'Call the clinic now' : 'Call $name',
                      icon: Ic.phone,
                      onPressed: () => _call(context, number, name),
                    ),
                  ],
                ),
              ),
              _Bullets(
                items: result.redFlags,
                icon: Ic.alert,
                tone: Tone.alert,
                heading: 'Serious signs we are acting on',
              ),
              _Bullets(
                items: result.bullets,
                icon: Ic.info,
                tone: Tone.mid,
                heading: 'While you travel',
              ),
              const SizedBox(height: T.s16),
              _NotADiagnosis(),
            ],
          ),
        ),
        StickyCta(
          extra: SecondaryButton(
            label: 'Chat clinic team about this',
            icon: Ic.chat,
            onPressed: () => _handoff(context, pet, result),
          ),
          child: PrimaryButton(
            label: open ? 'Call the clinic now' : 'Call $name',
            icon: Ic.phone,
            destructive: true,
            onPressed: () => _call(context, number, name),
          )),
      ],
    );
  }
}

/// Shared AI -> clinic handoff. No-ops safely when there is no pet yet.
Future<void> _handoff(BuildContext context, Pet? pet, TriageResult result) async {
  if (pet == null) return;
  AppScope.read(context).handOffToClinic(pet: pet, result: result);
  if (!context.mounted) return;
  await Navigator.of(context).pushReplacement(
    appRoute(ChatThreadScreen(threadId: 'th_clinic', openedWithPetId: pet.id)),
  );
}

class _NotADiagnosis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ic.svg(Ic.shield, color: p.textSecondary, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'This is guidance, not a diagnosis. Only a veterinarian who examines '
              'your pet can confirm what is going on.',
              style: Type.footnote(p),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text, required this.icon});
  final String text;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ic.svg(icon, color: p.accentText, size: 16),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: Type.footnote(p))),
        ],
      ),
    );
  }
}
