import 'package:flutter/cupertino.dart';

import '../../app.dart' show DetailNavBar;
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../services/ai_service.dart';
import '../../services/comms_service.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';

/// AI COMMS COMPOSER — the vet drafts, reviews, edits and approves every
/// outbound message. Never fully automatic.
///
/// One flow, top to bottom, no dead ends:
///   1. "What to say" — kind (announcement / reminder), topic + presets,
///      optional details → "Generate draft" (AI, via [CommsService]).
///   2. "Review the draft" — the vet edits the text; the state chip shows
///      where it sits; the explicit "Approve this message" button moves it
///      draft → approved. Editing an approved draft sends it back to draft.
///   3. "Channel & recipients" — in-app / email / SMS; SMS and email need
///      customer opt-in, and a blocked send names who is missing so the vet
///      can exclude them or switch channels.
///   4. "Send" — unlocked only after approval. The approval gate also lives
///      in [CommsService.sendDraft], so the UI can never bypass it.
///
/// Delivery itself is stubbed (no SMS/email provider wired yet — the spec
/// calls that out as needing a provider + budget); the send is recorded and
/// shown as sent.
class CommsScreen extends StatefulWidget {
  const CommsScreen({super.key});

  @override
  State<CommsScreen> createState() => _CommsScreenState();
}

class _CommsScreenState extends State<CommsScreen> {
  CommsService? _comms;
  CommsDraft? _draft;

  var _kind = CommsDraftKind.announcement;
  var _channel = CommsChannel.inApp;

  final _topic = TextEditingController();
  final _details = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();

  var _generating = false;
  String? _generateError;
  String? _sendError;

  static const _presets = [
    'Vaccination due',
    'Open grooming slots',
    'Holiday hours',
    'Post-visit follow-up',
    'Appointment reminder',
  ];

  @override
  void initState() {
    super.initState();
    // Defer to first frame: the store (and its bootstrapped AI service) is
    // above this route in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _comms = CommsService(ai: AppScope.read(context).ai);
      });
    });
  }

  @override
  void dispose() {
    _topic.dispose();
    _details.dispose();
    _subject.dispose();
    _body.dispose();
    _comms?.dispose();
    super.dispose();
  }

  CommsService get _service => _comms!;

  bool get _dirty => _draft != null && _draft!.state != CommsDraftState.sent;

  int _optedInCount(CommsChannel channel) =>
      _service.recipients.where((r) => r.optedInFor(channel)).length;

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _generateError = null;
    });
    try {
      final draft = await _service.generateDraft(
        kind: _kind,
        topic: _topic.text,
        details: _details.text,
        channel: _channel,
      );
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _channel = draft.channel;
        _subject.text = draft.subject;
        _body.text = draft.body;
        _sendError = null;
      });
    } on CommsException catch (e) {
      if (!mounted) return;
      setState(() => _generateError = e.message);
    } on AiException catch (e) {
      // No fake draft, ever: the AI's own failure copy says what to do.
      if (!mounted) return;
      setState(() => _generateError = '${e.failure.label}. ${e.failure.hint}');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _generateError = 'Could not reach the AI service. Check the connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Pushes the current field text into the draft through the state machine.
  /// Editing an approved draft revokes its approval — the new text must be
  /// re-approved before it can send.
  void _applyEdits() {
    final draft = _draft;
    if (draft == null || draft.state != CommsDraftState.draft) return;
    if (_subject.text == draft.subject && _body.text == draft.body) return;
    setState(() {
      _draft = _service.editDraft(
        draft,
        subject: _subject.text,
        body: _body.text,
      );
      _sendError = null;
    });
  }

  void _approve() {
    final draft = _draft;
    if (draft == null) return;
    _applyEdits();
    final current = _draft!;
    try {
      setState(() {
        _draft = _service.approveDraft(
          current,
          vetId: AppScope.read(context).auditStaffId,
        );
        _sendError = null;
      });
    } on CommsException catch (e) {
      setState(() => _sendError = e.message);
    }
  }

  void _setChannel(CommsChannel channel) {
    setState(() => _channel = channel);
    final draft = _draft;
    if (draft == null) return;
    try {
      setState(() {
        _draft = _service.setChannel(draft, channel);
        _sendError = null;
      });
    } on CommsException catch (e) {
      setState(() => _sendError = e.message);
    }
  }

  Future<void> _send() async {
    final draft = _draft;
    if (draft == null) return;
    _applyEdits();
    try {
      final sent = await _service.sendDraft(_draft!);
      if (!mounted) return;
      setState(() {
        _draft = sent;
        _sendError = null;
      });
    } on CommsException catch (e) {
      if (!mounted) return;
      setState(() => _sendError = e.message);
    }
  }

  /// The opt-in block offers a way forward: send to the customers who did
  /// opt in, keeping the content approval (the text is unchanged).
  void _excludeAndSend() {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _draft = _service.excludeNonOptedIn(draft);
    });
    _send();
  }

  void _reset() {
    setState(() {
      _draft = null;
      _topic.clear();
      _details.clear();
      _subject.clear();
      _body.clear();
      _generateError = null;
      _sendError = null;
      _channel = CommsChannel.inApp;
      _kind = CommsDraftKind.announcement;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final draft = _draft;
    final sent = draft?.state == CommsDraftState.sent;
    // AX5: segmented controls and pill wraps cannot survive 3.2x text — the
    // labels would clip ("Announ…"). Above 1x the selectors reflow into
    // full-width wrapping rows instead. 1x stays pixel-identical.
    final big = MediaQuery.textScalerOf(context).scale(1) > 1.0;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardIfDirty(
          context,
          isDirty: _dirty,
          title: 'Discard this draft?',
          message: 'The message has not been sent. Discarding throws away the draft.',
        )) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: const DetailNavBar(title: 'AI comms composer'),
        child: SafeArea(
          child: _comms == null
              ? const Center(child: CupertinoActivityIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(T.s16, T.s12, T.s16, 40),
                  children: [
                    if (sent)
                      _SentCard(draft: draft!, onComposeAnother: _reset)
                    else ...[
                      _sectionTitle(p, '1 · What to say'),
                      const SizedBox(height: T.s12),
                      if (big)
                        _ChoiceList(
                          options: const ['Announcement', 'Reminder'],
                          selected: _kind.index,
                          onSelect: (i) =>
                              setState(() => _kind = CommsDraftKind.values[i]),
                        )
                      else
                        SegmentedControl(
                          index: _kind.index,
                          labels: const ['Announcement', 'Reminder'],
                          onChanged: (i) =>
                              setState(() => _kind = CommsDraftKind.values[i]),
                        ),
                      const SizedBox(height: T.s12),
                      CupertinoTextField(
                        controller: _topic,
                        placeholder: 'Topic — e.g. Holiday hours',
                        style: Type.body(p),
                        placeholderStyle: Type.body(p)
                            .copyWith(color: p.textSecondary),
                        padding: const EdgeInsets.all(T.s12),
                        decoration: BoxDecoration(
                          color: p.fieldBg,
                          borderRadius: BorderRadius.circular(T.rControl),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: T.s12),
                      if (big)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final preset in _presets) ...[
                              _PresetRow(
                                label: preset,
                                selected: _topic.text == preset,
                                onTap: () =>
                                    setState(() => _topic.text = preset),
                              ),
                              const SizedBox(height: T.s8),
                            ],
                          ],
                        )
                      else
                        Wrap(
                          spacing: T.s8,
                          runSpacing: T.s8,
                          children: [
                            for (final preset in _presets)
                              FilterPill(
                                label: preset,
                                selected: _topic.text == preset,
                                onTap: () =>
                                    setState(() => _topic.text = preset),
                              ),
                          ],
                        ),
                      const SizedBox(height: T.s12),
                      CupertinoTextField(
                        controller: _details,
                        placeholder: 'Details for the AI (optional) — e.g. closed Dec 24–26',
                        style: Type.body(p),
                        placeholderStyle: Type.body(p)
                            .copyWith(color: p.textSecondary),
                        padding: const EdgeInsets.all(T.s12),
                        decoration: BoxDecoration(
                          color: p.fieldBg,
                          borderRadius: BorderRadius.circular(T.rControl),
                        ),
                        maxLines: 2,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: T.s12),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          onPressed: _generating ? null : _generate,
                          child: _generating
                              ? const CupertinoActivityIndicator(
                                  color: Color(0xFFFFFFFF),
                                )
                              : const Text('Generate draft with AI'),
                        ),
                      ),
                      if (_generateError != null) ...[
                        const SizedBox(height: T.s12),
                        _ErrorNote(message: _generateError!),
                      ],
                      if (draft != null) ...[
                        const SizedBox(height: T.s24),
                        _sectionTitle(p, '2 · Review the draft'),
                        const SizedBox(height: T.s8),
                        _StateRow(draft: draft),
                        const SizedBox(height: T.s12),
                        _draftField(
                          p,
                          controller: _subject,
                          label: 'Subject',
                          enabled: draft.state == CommsDraftState.draft,
                          onChanged: (_) => _applyEdits(),
                        ),
                        const SizedBox(height: T.s12),
                        _draftField(
                          p,
                          controller: _body,
                          label: 'Message',
                          enabled: draft.state == CommsDraftState.draft,
                          maxLines: 6,
                          onChanged: (_) => _applyEdits(),
                        ),
                        const SizedBox(height: T.s12),
                        if (draft.state == CommsDraftState.draft) ...[
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              onPressed: _approve,
                              child: const Text('Approve this message'),
                            ),
                          ),
                          const SizedBox(height: T.s8),
                          Text(
                            'Nothing sends until you approve it. Approving '
                            'locks this exact text, channel and recipients.',
                            style: Type.footnote(p)
                                .copyWith(color: p.textSecondary),
                          ),
                        ] else ...[
                          _InfoNote(
                            icon: Ic.check,
                            message:
                                'Approved — this exact text is ready to send. '
                                'Editing it will ask for approval again.',
                          ),
                        ],
                        const SizedBox(height: T.s24),
                        _sectionTitle(p, '3 · Channel & recipients'),
                        const SizedBox(height: T.s12),
                        if (big)
                          _ChoiceList(
                            options: const ['In-app', 'Email', 'SMS'],
                            selected: _channel.index,
                            onSelect: (i) =>
                                _setChannel(CommsChannel.values[i]),
                          )
                        else
                          SegmentedControl(
                            index: _channel.index,
                            labels: const ['In-app', 'Email', 'SMS'],
                            onChanged: (i) =>
                                _setChannel(CommsChannel.values[i]),
                          ),
                        const SizedBox(height: T.s8),
                        Text(
                          _recipientLine(draft),
                          style: Type.footnote(p)
                              .copyWith(color: p.textSecondary),
                        ),
                        const SizedBox(height: T.s24),
                        _sectionTitle(p, '4 · Send'),
                        const SizedBox(height: T.s12),
                        if (draft.state == CommsDraftState.draft) ...[
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              onPressed: null,
                              child: const Text('Send message'),
                            ),
                          ),
                          const SizedBox(height: T.s8),
                          Text(
                            'Review the draft above and approve it first — '
                            'an unapproved draft can never send.',
                            style: Type.footnote(p)
                                .copyWith(color: p.textSecondary),
                          ),
                        ] else ...[
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              onPressed: _send,
                              child: const Text('Send message'),
                            ),
                          ),
                        ],
                        if (_sendError != null) ...[
                          const SizedBox(height: T.s12),
                          _ErrorNote(message: _sendError!),
                          if (_sendError!.contains('not opted in')) ...[
                            const SizedBox(height: T.s8),
                            SizedBox(
                              height: 44,
                              width: double.infinity,
                              child: CupertinoButton(
                                onPressed: _excludeAndSend,
                                child: Text(
                                  'Send to the ${_optedInCount(draft.channel)} who opted in',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  /// "N customers · M opted in to SMS" — the directory is stub data until the
  /// customer opt-in backend lands, and the line says so.
  String _recipientLine(CommsDraft draft) {
    final total = draft.recipients.length;
    if (!draft.channel.requiresOptIn) {
      return '$total customers will see it in the app. (recipient list is sample data until the opt-in backend lands)';
    }
    final optedIn = _optedInCount(draft.channel);
    return '$optedIn of $total customers opted in to ${draft.channel.label}. '
        'Sending to anyone else is blocked. (sample data until the opt-in backend lands)';
  }

  Widget _sectionTitle(AppPalette p, String title) => Text(
    title,
    style: Type.headline(p),
    semanticsLabel: title.replaceAll(' · ', ', '),
  );

  Widget _draftField(
    AppPalette p, {
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Type.footnoteEmph(p)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 4 : 1,
          style: Type.body(p),
          padding: const EdgeInsets.all(T.s12),
          decoration: BoxDecoration(
            color: enabled ? p.fieldBg : p.fieldBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(T.rControl),
          ),
        ),
      ],
    );
  }
}

class _StateRow extends StatelessWidget {
  const _StateRow({required this.draft});
  final CommsDraft draft;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Row(
      children: [
        StatusChip(
          label: draft.state.label,
          icon: switch (draft.state) {
            CommsDraftState.draft => Ic.pencil,
            CommsDraftState.approved => Ic.check,
            CommsDraftState.sent => Ic.send,
          },
        ),
        const SizedBox(width: T.s8),
        Expanded(
          child: Text(switch (draft.state) {
            CommsDraftState.draft =>
              'AI-drafted. Review it, edit freely, then approve.',
            CommsDraftState.approved => 'Approved by the vet. Ready to send.',
            CommsDraftState.sent => 'Sent.',
          }, style: Type.footnote(p).copyWith(color: p.textSecondary)),
        ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(T.s12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(T.rControl),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 16,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: T.s8),
            Expanded(child: Text(message, style: Type.footnote(p))),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.message});
  final String icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.all(T.s12),
      decoration: BoxDecoration(
        color: p.fieldBg,
        borderRadius: BorderRadius.circular(T.rControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Ic.svg(icon, color: p.accentText, size: 16, stroke: 2),
          ),
          const SizedBox(width: T.s8),
          Expanded(
            child: Text(
              message,
              style: Type.footnote(p).copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width wrapping option rows: the AX5 reflow for [SegmentedControl]
/// and the preset [FilterPill] wrap. Above 1x text, segmented labels clip
/// ("Announ…") and wide pills overflow the viewport — rows wrap instead.
/// 1x never renders this; it keeps the segmented controls and pills.
class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      label: 'Options. ${options[selected]} selected',
      child: SoftCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) Divider(height: 1, color: p.divider, indent: T.s16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: T.s16,
                    vertical: T.s12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          options[i],
                          style: Type.body(p).copyWith(
                            fontWeight: i == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (i == selected)
                        Ic.svg(
                          Ic.check,
                          color: p.accentText,
                          size: 18,
                          stroke: 2.5,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-width wrapping preset row: the AX5 reflow for the preset pill wrap.
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: T.s16,
              vertical: T.s12,
            ),
            decoration: BoxDecoration(
              color: selected ? p.primaryFill : p.surface,
              borderRadius: BorderRadius.circular(T.rPill),
              border: Border.all(color: selected ? p.primaryFill : p.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Type.footnote(p).copyWith(
                      color: selected ? p.onPrimaryFill : p.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  Ic.svg(
                    Ic.check,
                    color: p.onPrimaryFill,
                    size: 16,
                    stroke: 2.5,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SentCard extends StatelessWidget {
  const _SentCard({required this.draft, required this.onComposeAnother});
  final CommsDraft draft;
  final VoidCallback onComposeAnother;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: T.s24),
        SoftCard(
          padding: const EdgeInsets.all(T.s20),
          child: Column(
            children: [
              Ic.svg(Ic.check, color: p.accentText, size: 40, stroke: 2),
              const SizedBox(height: T.s12),
              Text(
                'Message sent',
                style: Type.title2(p),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s8),
              Text(
                '${draft.channel.label} · ${draft.recipients.length} customer${draft.recipients.length == 1 ? '' : 's'}',
                style: Type.footnote(p).copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s4),
              Text(
                '“${draft.subject}”',
                style: Type.footnoteEmph(p),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: T.s16),
        SizedBox(
          height: 48,
          child: CupertinoButton.filled(
            onPressed: onComposeAnother,
            child: const Text('Compose another message'),
          ),
        ),
      ],
    );
  }
}
