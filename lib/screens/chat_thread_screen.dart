import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../data/clinic.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../services/ai_service.dart';
import '../state/app_store.dart';
import '../widgets/ai_unavailable.dart';
import '../widgets/common.dart';
import 'appointments/book_flow.dart';
import 'chats_screen.dart';
import 'profile/settings_screens.dart';
import 'triage_screen.dart';

/// A conversation thread. The CarePaws AI thread also carries the
/// "Start health check" entry point into the triage engine.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.threadId,
    this.openedWithPetId,
    this.triageSummary,
  });

  final String threadId;

  /// Set when arriving from an AI → clinic handoff.
  final String? openedWithPetId;
  final String? triageSummary;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _showStaff = false;

  bool get _isAi => widget.threadId == 'th_ai';

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _scroll.addListener(_maybeAutoScroll);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _maybeAutoScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) {
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: T.springMs),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollToEnd();
  }

  /// Asks the real model. Any failure (no key, network, API error) comes
  /// back as an explicit "AI unavailable" bubble — never a canned answer.
  Future<String> _askAi(AppStore store, Pet? pet, String text) async {
    try {
      return await store.ai.chat(
        petName: pet?.name ?? 'your pet',
        species: pet?.breed ?? 'dog',
        question: text,
        ownerFirstName: store.ownerFirstName,
      );
    } on AiException catch (e) {
      return aiUnavailableText(e.failure);
    }
  }

  static String _thanks(AppStore store) {
    final first = store.ownerFirstName;
    return first.isEmpty ? 'Thanks' : 'Thanks, $first';
  }

  Future<void> _send() => _sendText(_input.text.trim());

  Future<void> _sendText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final store = AppScope.read(context);
    final pet = store.pet(
      widget.openedWithPetId ?? store.pets.firstOrNull?.id ?? '',
    );
    _input.clear();
    setState(() => _sending = true);

    store.pushMessage(
      ChatMessage(
        id: 'u${store.now.microsecondsSinceEpoch}',
        threadId: widget.threadId,
        author: _isAi ? ChatAuthor.ai : ChatAuthor.vetAssistant,
        text: text,
        at: store.now,
        sentByMe: true,
        petId: pet?.id,
      ),
    );
    _scrollToEnd();

    final reply = _isAi
        ? await _askAi(store, pet, text)
        : (store.staffOnline()
              ? '${_thanks(store)} — noted on ${pet?.name ?? 'that'}. I will check the chart and come back '
                    'to you with a recommendation. If anything changes in the meantime, call the clinic.'
              : 'Got your message. The clinic team is offline until 9:00 AM, so reply may take a few '
                    'hours. For anything urgent, call ${Seed.clinicPhone}.');

    if (!mounted) return;
    setState(() => _sending = false);
    store.pushMessage(
      ChatMessage(
        id: 'a${store.now.microsecondsSinceEpoch + 1}',
        threadId: widget.threadId,
        author: _isAi ? ChatAuthor.ai : ChatAuthor.vetAssistant,
        text: reply,
        at: store.now.add(const Duration(minutes: 1)),
        petId: pet?.id,
      ),
    );
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final thread = Seed.threads.firstWhere((t) => t.id == widget.threadId);
    final messages = store.thread(thread.id);

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: thread.title,
        actions: [
          if (!_isAi)
            IconTap(
              path: Ic.person,
              label: 'Clinic team',
              color: p.primaryFill,
              onPressed: () => setState(() => _showStaff = !_showStaff),
            ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _ThreadIdentity(isAi: _isAi, store: store),
            if (_isAi && store.ai.status == AiStatus.unavailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AiUnavailableCard(
                  failure: store.ai.failure ?? AiFailure.noKey,
                  onOpenSettings: () =>
                      Navigator.of(context)
                          .push(appRoute(const AiSettingsScreen())),
                  onBook: () =>
                      Navigator.of(context).push(appRoute(const BookFlow())),
                  onCall: () => callPhoneNumber(
                    context,
                    number: Clinic.phone,
                    name: Clinic.name,
                  ),
                ),
              ),
            if (!_isAi && store.offlineNote != null)
              _OfflineBanner(text: store.offlineNote!),
            if (_showStaff && !_isAi) const StaffDirectory(),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyThread(
                      isAi: _isAi,
                      onAction: _isAi ? _startCheck : null,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[i];
                        return _Bubble(
                          message: m,
                          isAi: _isAi,
                          petName: store.pet(m.petId ?? '')?.name,
                        );
                      },
                    ),
            ),
            if (_sending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(color: p.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      _isAi
                          ? 'CarePaws AI is typing…'
                          : 'Clinic team is typing…',
                      style: Type.caption(p),
                    ),
                  ],
                ),
              ),
            _SuggestionChips(
              isAi: _isAi,
              onHealthCheck: _startCheck,
              onSend: _sendText,
            ),
            _Composer(
              controller: _input,
              onSend: _send,
              hint: _isAi
                  ? 'Ask about feeding, grooming or vaccines'
                  : 'Message the clinic team',
            ),
          ],
        ),
      ),
    );
  }

  void _startCheck() {
    Navigator.of(context).push(
      appRoute(
        TriageScreen(
          entry: TriageEntry.aiChat,
          preselectedPetId: widget.openedWithPetId,
        ),
      ),
    );
  }
}

/// One compact identity row under the nav bar — avatar, name, and a single
/// status line. It replaces the old amber banner + full-width health-check
/// card, which repeated the same information three times.
class _ThreadIdentity extends StatelessWidget {
  const _ThreadIdentity({required this.isAi, required this.store});
  final bool isAi;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final online = store.staffOnline();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isAi
                  ? T.amber.withValues(alpha: 0.24)
                  : p.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Ic.svg(
                isAi ? Ic.sparkle : Ic.chat,
                color: isAi ? p.primaryFill : p.accent,
                size: 16,
                stroke: 2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isAi ? 'CarePaws AI' : 'Clinic team',
                  style: Type.footnoteEmph(p),
                ),
                Text(
                  isAi
                      ? 'AI assistant · General guidance, not a diagnosis'
                      : online
                      ? 'Online now · usually replies in ~10 min'
                      : 'Replies during clinic hours',
                  style: Type.caption(p).copyWith(color: p.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Suggestion chips above the composer: one-tap entry points that used to
/// live in the bulky health-check card (AI) or needed typing out (clinic).
class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({
    required this.isAi,
    required this.onHealthCheck,
    required this.onSend,
  });
  final bool isAi;
  final VoidCallback onHealthCheck;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final chips = isAi
        ? <(String, String, VoidCallback)>[
            ('Start health check', Ic.sparkle, onHealthCheck),
            ('Feeding', Ic.bone, () => onSend('Any feeding tips for my pet?')),
            (
              'Vaccines',
              Ic.shield,
              () => onSend('What vaccines does my pet need?'),
            ),
            (
              'Grooming',
              Ic.scissors,
              () => onSend('How often should I groom my pet?'),
            ),
          ]
        : <(String, String, VoidCallback)>[
            (
              'My appointment',
              Ic.calendar,
              () => onSend('I have a question about my appointment.'),
            ),
            (
              'Prescription refill',
              Ic.pill,
              () => onSend('I would like to request a prescription refill.'),
            ),
            (
              'Billing question',
              Ic.wallet,
              () => onSend('I have a question about my bill.'),
            ),
          ];
    return Container(
      height: 44,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, icon, action) = chips[i];
          final primary = i == 0 && isAi;
          return PressScale(
            onTap: action,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: primary ? p.primaryFill : p.surface,
                borderRadius: BorderRadius.circular(T.rPill),
                border: Border.all(color: primary ? p.primaryFill : p.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Ic.svg(
                    icon,
                    color: primary ? p.onPrimaryFill : p.accentText,
                    size: 14,
                    stroke: 2.2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Type.footnote(p).copyWith(
                      color: primary ? p.onPrimaryFill : p.accentText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: T.amber.withValues(alpha: 0.16),
      child: Row(
        children: [
          Ic.svg(Ic.clock, color: p.accentText, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Type.caption(p).copyWith(color: p.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.isAi, required this.onAction});
  final bool isAi;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return EmptyState(
      icon: isAi ? Ic.sparkle : Ic.chat,
      title: isAi ? 'Start a health check' : 'Message the clinic team',
      body: isAi
          ? 'Ask a general care question, or run a health check to be routed to booking, chat or home care.'
          : 'Ask about an appointment, a prescription or a billing question. Miguel replies during clinic hours.',
      actionLabel: isAi ? 'Start health check' : 'Ask about my appointment',
      onAction:
          onAction ??
          () => showAppSheet(
            context,
            scrollable: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Quick options', style: Type.title2(p)),
                  const SizedBox(height: 6),
                  Text(
                    'Type your question below and it goes straight to the clinic inbox.',
                    style: Type.footnote(p),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: T.s20),
                  PrimaryButton(
                    label: 'Got it',
                    onPressed: () => dismissSheet(context),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isAi, this.petName});

  final ChatMessage message;
  final bool isAi;
  final String? petName;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final mine = message.sentByMe;

    if (message.kind == ChatKind.triageHandoff) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SoftCard(
          padding: const EdgeInsets.all(14),
          color: T.amber.withValues(alpha: 0.14),
          borderColor: p.accent.withValues(alpha: 0.28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Ic.svg(Ic.sparkle, color: p.accent, size: 16),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Health check handed off',
                      style: Type.headline(p),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (petName != null)
                StatusChip(label: petName!, icon: Ic.paw, compact: true),
              const SizedBox(height: 8),
              Text(message.text, style: Type.body(p)),
            ],
          ),
        ),
      );
    }

    if (message.kind == ChatKind.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.fieldBg,
              borderRadius: BorderRadius.circular(T.rPill),
            ),
            child: Text(
              message.text,
              style: Type.caption(p),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final fromAi = message.author == ChatAuthor.ai;
    final bg = mine
        ? p.primaryFill
        : fromAi
        ? p.surface
        : p.surfaceAlt;
    final fg = mine ? p.onPrimaryFill : p.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                children: [
                  if (fromAi)
                    Ic.svg(Ic.sparkle, color: p.accent, size: 13, stroke: 2.2)
                  else
                    Ic.svg(Ic.chat, color: p.textSecondary, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    fromAi ? 'CarePaws AI' : _roleName(message.author),
                    style: Type.caption(p)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          Semantics(
            label:
                '${mine
                    ? 'You'
                    : fromAi
                    ? 'CarePaws AI'
                    : _roleName(message.author)} said: ${message.text}',
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 5),
                    bottomRight: Radius.circular(mine ? 5 : 18),
                  ),
                  border: Border.all(color: mine ? p.primaryFill : p.divider),
                ),
                child: Text(
                  message.text,
                  style: Type.body(p).copyWith(color: fg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _roleName(ChatAuthor a) => switch (a) {
    ChatAuthor.vet => 'Dr. Alvarez · Veterinarian',
    ChatAuthor.vetAssistant => 'Miguel · Vet Assistant',
    ChatAuthor.groomer => 'Ana · Groomer',
    ChatAuthor.ai => 'CarePaws AI',
  };
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.hint,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final can = controller.text.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        10 + MediaQuery.paddingOf(context).bottom * 0.2,
      ),
      decoration: BoxDecoration(
        color: p.background.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: p.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: hint,
              placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
              style: Type.body(p),
              minLines: 1,
              maxLines: 5,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              cursorColor: p.primaryFill,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.divider),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            enabled: can,
            label: 'Send message',
            child: ExcludeSemantics(
              child: PressScale(
                onTap: can ? onSend : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: can ? p.primaryFill : p.fieldBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Ic.svg(
                      Ic.send,
                      color: can ? p.onPrimaryFill : p.textSecondary,
                      size: 20,
                      stroke: 2.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
