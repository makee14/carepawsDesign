import 'package:flutter/foundation.dart';

import 'ai_service.dart';

/// ---------------------------------------------------------------------------
/// AI comms composer state machine (vet portal, Task 7).
///
/// A comms draft moves draft → approved → sent. The approval gate lives here,
/// not in the UI: [CommsService.sendDraft] refuses any draft that has not
/// been explicitly approved by a vet. There are no auto-approve paths —
/// generation, editing and re-scoping never change the state upward.
///
/// SMS and email require customer opt-in. Sending via those channels to a
/// non-opted-in customer is blocked with the names spelled out, so the vet
/// can exclude them or switch to in-app announcements instead.
///
/// STUBBED until the backend lands:
/// - The opt-in directory ([CommsService.stubDirectory]) is sample data.
///   The real source is the customer table's opt-in columns.
/// - Delivery itself: [sendDraft] records the send; no SMS/email provider is
///   wired (the spec calls out SMS as needing a provider + budget first).
/// ---------------------------------------------------------------------------

/// What kind of message the AI is drafting.
enum CommsDraftKind { announcement, reminder }

extension CommsDraftKindX on CommsDraftKind {
  String get label => switch (this) {
    CommsDraftKind.announcement => 'Announcement',
    CommsDraftKind.reminder => 'Reminder',
  };
}

/// Where an approved draft goes out.
enum CommsChannel { inApp, email, sms }

extension CommsChannelX on CommsChannel {
  String get label => switch (this) {
    CommsChannel.inApp => 'In-app announcement',
    CommsChannel.email => 'Email',
    CommsChannel.sms => 'SMS',
  };

  /// Email and SMS are outbound contact — the spec requires customer opt-in
  /// before any of it. In-app announcements live inside the app, no opt-in.
  bool get requiresOptIn => this != CommsChannel.inApp;
}

/// Where a draft sits in the draft → approved → sent machine.
enum CommsDraftState { draft, approved, sent }

extension CommsDraftStateX on CommsDraftState {
  String get label => switch (this) {
    CommsDraftState.draft => 'Draft',
    CommsDraftState.approved => 'Approved',
    CommsDraftState.sent => 'Sent',
  };
}

/// A message the vet clinic cannot act on: unapproved sends, blocked sends.
class CommsException implements Exception {
  const CommsException(this.message);
  final String message;

  @override
  String toString() => 'CommsException: $message';
}

/// One customer, with their outreach opt-ins.
///
/// STUB: until the backend lands, the directory below is sample data. The
/// real opt-ins come from the customer table and the customer's own
/// notification settings.
@immutable
class CommsRecipient {
  const CommsRecipient({
    required this.id,
    required this.name,
    this.smsOptIn = false,
    this.emailOptIn = false,
  });

  final String id;
  final String name;
  final bool smsOptIn;
  final bool emailOptIn;

  bool optedInFor(CommsChannel channel) => switch (channel) {
    CommsChannel.inApp => true,
    CommsChannel.email => emailOptIn,
    CommsChannel.sms => smsOptIn,
  };
}

/// One AI-drafted message, immutable: every transition returns a new draft.
@immutable
class CommsDraft {
  const CommsDraft({
    required this.id,
    required this.kind,
    required this.subject,
    required this.body,
    required this.channel,
    required this.recipients,
    required this.state,
    required this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.sentAt,
  });

  final String id;
  final CommsDraftKind kind;
  final String subject;
  final String body;
  final CommsChannel channel;
  final List<CommsRecipient> recipients;
  final CommsDraftState state;
  final DateTime createdAt;

  /// The vet who explicitly approved this text. Null unless approved.
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? sentAt;

  CommsDraft copyWith({
    String? subject,
    String? body,
    CommsChannel? channel,
    List<CommsRecipient>? recipients,
    CommsDraftState? state,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? sentAt,
    bool clearApproval = false,
  }) => CommsDraft(
    id: id,
    kind: kind,
    subject: subject ?? this.subject,
    body: body ?? this.body,
    channel: channel ?? this.channel,
    recipients: recipients ?? this.recipients,
    state: state ?? this.state,
    createdAt: createdAt,
    approvedBy: clearApproval ? null : (approvedBy ?? this.approvedBy),
    approvedAt: clearApproval ? null : (approvedAt ?? this.approvedAt),
    sentAt: sentAt ?? this.sentAt,
  );
}

/// Generates draft text. The default talks to [AiService]; tests inject a
/// stub so no real API is ever called from a test.
typedef CommsDraftGenerator = Future<String> Function({
  required CommsDraftKind kind,
  required String topic,
  String? details,
});

/// The comms composer: AI drafting plus the approval-gated send machine.
class CommsService {
  CommsService({
    CommsDraftGenerator? draftGenerator,
    AiService? ai,
    List<CommsRecipient>? recipients,
  }) : _ai = ai ?? AiService(),
       _recipients = recipients ?? stubDirectory() {
    // One AI instance: the default generator closes over the same service
    // that [dispose] shuts down.
    _generator =
        draftGenerator ??
        (({required kind, required topic, String? details}) =>
            _ai.draftComms(kind: kind.label, topic: topic, details: details));
  }

  final AiService _ai;
  late final CommsDraftGenerator _generator;
  final List<CommsRecipient> _recipients;

  /// STUB: sample customer opt-ins until the customer opt-in backend lands.
  /// Marked as stub data everywhere it surfaces.
  static List<CommsRecipient> stubDirectory() => const [
    CommsRecipient(
      id: 'c1',
      name: 'Ana Reyes',
      smsOptIn: true,
      emailOptIn: true,
    ),
    CommsRecipient(id: 'c2', name: 'Miguel Cruz', emailOptIn: true),
    CommsRecipient(id: 'c3', name: 'Jose Ramos'),
    CommsRecipient(id: 'c4', name: 'Liza Santos', smsOptIn: true),
  ];

  List<CommsRecipient> get recipients => List.unmodifiable(_recipients);

  /// Drafts message text with the AI. Never approves — the result is always
  /// a [CommsDraftState.draft] waiting for the vet's review and explicit
  /// approval. An AI failure throws to the caller: no fake draft, ever.
  Future<CommsDraft> generateDraft({
    required CommsDraftKind kind,
    required String topic,
    String? details,
    CommsChannel channel = CommsChannel.inApp,
  }) async {
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty) {
      throw const CommsException(
        'Add a topic first so the AI has something to draft about.',
      );
    }
    final body = (await _generator(
      kind: kind,
      topic: cleanTopic,
      details: details?.trim().isEmpty ?? true ? null : details!.trim(),
    )).trim();
    if (body.isEmpty) {
      throw const CommsException(
        'The AI draft came back empty. Try generating again.',
      );
    }
    return CommsDraft(
      id: 'comms-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      subject: cleanTopic,
      body: body,
      channel: channel,
      recipients: _recipients,
      state: CommsDraftState.draft,
      createdAt: DateTime.now(),
    );
  }

  /// The vet edits the AI draft. Editing an *approved* draft revokes the
  /// approval — the new text must be re-approved before it can send.
  CommsDraft editDraft(CommsDraft draft, {String? subject, String? body}) {
    _requireMutable(draft);
    return draft.copyWith(
      subject: subject,
      body: body,
      // An approved draft's text changed: the old approval no longer covers
      // it, so it goes back to draft. No auto paths, ever.
      state: draft.state == CommsDraftState.approved
          ? CommsDraftState.draft
          : null,
      clearApproval: draft.state == CommsDraftState.approved,
    );
  }

  /// The vet switches the outbound channel. Like an edit, a channel change
  /// on an approved draft revokes the approval — the vet approved a
  /// specific message on a specific channel.
  CommsDraft setChannel(CommsDraft draft, CommsChannel channel) {
    _requireMutable(draft);
    if (channel == draft.channel) return draft;
    return draft.copyWith(
      channel: channel,
      state: draft.state == CommsDraftState.approved
          ? CommsDraftState.draft
          : null,
      clearApproval: draft.state == CommsDraftState.approved,
    );
  }

  /// Narrows the draft to recipients who opted in to its channel. This
  /// changes who receives the message, not what it says, so a content
  /// approval still stands.
  CommsDraft excludeNonOptedIn(CommsDraft draft) {
    _requireMutable(draft);
    return draft.copyWith(
      recipients: draft.recipients
          .where((r) => r.optedInFor(draft.channel))
          .toList(),
    );
  }

  /// The explicit vet action: approves this exact text, channel and
  /// recipient set for sending. Only a draft can be approved.
  CommsDraft approveDraft(CommsDraft draft, {required String vetId}) {
    if (draft.state != CommsDraftState.draft) {
      throw CommsException(
        'Only a draft can be approved (this one is ${draft.state.label.toLowerCase()}).',
      );
    }
    if (draft.body.trim().isEmpty) {
      throw const CommsException(
        'The draft is empty — write or generate the message first.',
      );
    }
    return draft.copyWith(
      state: CommsDraftState.approved,
      approvedBy: vetId,
      approvedAt: DateTime.now(),
    );
  }

  /// Sends an approved draft. THE GATE: anything that is not approved
  /// refuses loudly — this is the state-machine backstop behind the UI.
  /// Email/SMS also refuse when any recipient has not opted in, naming them.
  ///
  /// STUB: delivery itself is recorded, not performed — no SMS/email
  /// provider is wired yet (the spec calls out SMS as needing a provider +
  /// budget first).
  Future<CommsDraft> sendDraft(CommsDraft draft) async {
    if (draft.state != CommsDraftState.approved) {
      throw CommsException(
        'This message cannot send yet — a vet must review and approve the draft first.',
      );
    }
    if (draft.channel.requiresOptIn) {
      final missing = draft.recipients
          .where((r) => !r.optedInFor(draft.channel))
          .map((r) => r.name)
          .toList();
      if (missing.isNotEmpty) {
        throw CommsException(
          'Cannot send via ${draft.channel.label}: '
          '${missing.length} customer${missing.length == 1 ? ' has' : 's have'} '
          'not opted in (${missing.join(', ')}). '
          'Exclude them or switch to an in-app announcement instead.',
        );
      }
    }
    // STUB: no outbound provider. The send is recorded; wiring a provider
    // (and the SMS budget) is a backend task.
    return draft.copyWith(state: CommsDraftState.sent, sentAt: DateTime.now());
  }

  void _requireMutable(CommsDraft draft) {
    if (draft.state == CommsDraftState.sent) {
      throw const CommsException('A sent message cannot be changed.');
    }
  }

  void dispose() => _ai.dispose();
}
