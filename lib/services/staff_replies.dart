import '../data/clinic.dart';
import '../data/models.dart';
import '../data/seed.dart';

/// Composes the clinic team's chat replies.
///
/// Replies are generated from the user's *actual* message: an intent scan
/// picks the topic (grooming, booking, hours, symptoms, …) and each role
/// answers in its own voice — groomer, vet assistant, veterinarian — so the
/// reply references the specific inquiry instead of reading as a canned
/// auto-response.
///
/// Tone rule (Mark): intuitive and friendly, never anxiety-inducing. The vet
/// never diagnoses remotely: symptoms get one clarifying question and, when
/// warranted, a nudge toward the clinic — never alarm.
String composeStaffReply({
  required StaffRole role,
  required String userText,
  required String petName,
  required bool clinicOpen,
  bool photoSent = false,
}) {
  final text = userText.toLowerCase();
  final closedNote = clinicOpen
      ? ''
      : " We're closed right now — back at ${Clinic.openTimeLabel}, and I'll pick this up "
            'first thing.';
  final urgentNote = clinicOpen
      ? ''
      : ' If $petName seems distressed or this worsens, call the clinic now '
            'at ${Clinic.phone} rather than waiting.';

  if (photoSent) {
    return switch (role) {
      StaffRole.groomer =>
        'Got the photo! I\u2019ll take a look and let you know what we can do '
            'for $petName.$closedNote',
      StaffRole.vet =>
        'Thanks — I can see the photo. I\u2019ll have a proper look at $petName '
            'and let you know what I think.$closedNote',
      StaffRole.vetAssistant =>
        'Photo received — I\u2019ll take a look at $petName and get back to '
            'you here.$closedNote',
    };
  }

  if (_hasAny(text, const ['health check', 'triage', 'check result'])) {
    return switch (role) {
      StaffRole.groomer =>
        'Got $petName\u2019s health check — I\u2019ll pass it straight to the '
            'vet team and get back to you here.$closedNote',
      StaffRole.vet =>
        'I\u2019ve got $petName\u2019s health check results. Let me review them '
            'properly and I\u2019ll share my recommendation here.$closedNote',
      StaffRole.vetAssistant =>
        'I have $petName\u2019s health check — I\u2019ll review the chart and '
            'reply here with a recommendation.$closedNote',
    };
  }

  if (_hasAny(text, const [
    'groom',
    'nail',
    'bath',
    'haircut',
    'trim',
    'fur',
    'shampoo',
  ])) {
    return switch (role) {
      StaffRole.groomer => _groomerGrooming(text, petName, closedNote),
      StaffRole.vet =>
        'Grooming-wise that\u2019s best answered by Ana, our groomer — I\u2019ll '
            'ask her to reply here about $petName.$closedNote',
      StaffRole.vetAssistant =>
        'That\u2019s Ana\u2019s department — our groomer. I\u2019ll check her '
            'book for $petName and get back to you here.$closedNote',
    };
  }

  if (_hasAny(text, const [
    'book',
    'appointment',
    'schedule',
    'reschedule',
    'slot',
    'available',
    'move',
    'cancel',
  ])) {
    return switch (role) {
      StaffRole.groomer =>
        'For grooming slots I can book $petName directly — which day suits '
            'you?$closedNote',
      StaffRole.vet =>
        'Miguel handles our schedule — I\u2019ll ask him to confirm $petName\u2019s '
            'slot and reply here.$closedNote',
      StaffRole.vetAssistant => _assistantBooking(text, petName, closedNote),
    };
  }

  if (_hasAny(text, const [
    'hour',
    'open',
    'close',
    'address',
    'where',
    'location',
    'phone',
    'number',
    'holiday',
  ])) {
    final hours = clinicOpen
        ? 'We\u2019re open now until 6:00 PM — message here or walk in and '
              'we\u2019ll fit $petName in.'
        : 'We\u2019re closed right now — back at ${Clinic.openTimeLabel}, Monday to Saturday.';
    return switch (role) {
      StaffRole.groomer =>
        '$hours Grooming walk-ins are welcome any time before 5 PM.',
      StaffRole.vet => '$hours$urgentNote',
      StaffRole.vetAssistant => '$hours Anything else I can sort?$urgentNote',
    };
  }

  final symptom = _matchSymptom(text, petName);
  if (symptom != null) {
    return switch (role) {
      StaffRole.vet =>
        'Thanks for telling me — ${symptom.label} can have a few common '
            'causes, so I won\u2019t guess from here. Can you tell me '
            '${symptom.followUp}? ${symptom.escalation}$closedNote$urgentNote',
      StaffRole.groomer =>
        'That sounds like a vet question rather than grooming — I\u2019ll loop '
            'in Dr. Alvarez so $petName gets the right eyes on it. Can you '
            'tell me ${symptom.followUp} in the meantime?$closedNote$urgentNote',
      StaffRole.vetAssistant =>
        'I\u2019ll flag this for Dr. Alvarez — $petName\u2019s ${symptom.label} '
            'is worth a proper look. Can you tell me ${symptom.followUp}? '
            'I\u2019ll reply here once he\u2019s reviewed it.$closedNote$urgentNote',
    };
  }

  return switch (role) {
    StaffRole.groomer =>
      'Got it! I\u2019ll check on that for $petName and reply here.$closedNote',
    StaffRole.vet =>
      'Thanks — I\u2019ll review $petName\u2019s notes and get back to you '
          'here.$closedNote',
    StaffRole.vetAssistant =>
      'Got it — I\u2019ll look into that for $petName and reply here. '
          'Anything else in the meantime?$closedNote',
  };
}

String _groomerGrooming(String text, String petName, String closedNote) {
  if (text.contains('nail')) {
    return 'No appointment needed for nails — walk in any time before 5 PM '
        'and we\u2019ll fit $petName in. Takes about 15 minutes!$closedNote';
  }
  if (_hasAny(text, const ['price', 'cost', 'how much', 'rate'])) {
    // Price from the seed service list (sv4 = Full Grooming) so the reply
    // can never drift from the booking flow's price.
    final groomPrice = Seed.services
        .firstWhere((s) => s.id == 'sv4')
        .price
        .round();
    return 'A full groom for $petName is \u20B1$groomPrice — bath, cut, '
        'nails, and ears included. Want me to find you a slot?$closedNote';
  }
  return 'Happy to help with $petName\u2019s grooming — bath, cut, nails? '
      'Tell me what you\u2019re after and I\u2019ll sort the right '
      'slot.$closedNote';
}

String _assistantBooking(String text, String petName, String closedNote) {
  if (text.contains('cancel')) {
    return 'No problem — tell me which visit to cancel for $petName and I\u2019ll '
        'free the slot, no charge.$closedNote';
  }
  final day = _mentionedDay(text);
  if (day != null) {
    return '$day works — I\u2019ll hold a slot for $petName and confirm the '
        'time here shortly.$closedNote';
  }
  return 'I can sort that for $petName — what day and time suits you? I\u2019ll '
      'confirm the slot here.$closedNote';
}

String? _mentionedDay(String text) {
  for (final d in const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
    'tomorrow',
    'today',
  ]) {
    if (text.contains(d)) return d[0].toUpperCase() + d.substring(1);
  }
  return null;
}

bool _hasAny(String text, List<String> keys) =>
    keys.any((k) => text.contains(k));

/// A matched symptom: how to name it, the one clarifying question to ask,
/// and when to nudge toward the clinic. Never a diagnosis, never alarm.
class _Symptom {
  const _Symptom(this.label, this.followUp, this.escalation);
  final String label;
  final String followUp;
  final String escalation;
}

/// Keywords that trigger each symptom entry, in the same order as above.
bool _symptomHit(String label, String text) => switch (label) {
  'bleeding' => _hasAny(text, const ['bleed', 'blood']),
  'breathing changes' => _hasAny(text, const [
    'breath',
    'pant',
    'wheez',
    'gasp',
  ]),
  'vomiting' => _hasAny(text, const ['vomit', 'throw up', 'throwing up']),
  'diarrhea' => _hasAny(text, const ['diarrhea', 'diarrhoea', 'loose stool']),
  'limping' => _hasAny(text, const ['limp', 'leg', 'paw']),
  'scratching' => _hasAny(text, const ['scratch', 'itch']),
  'appetite change' => _hasAny(text, const [
    'not eat',
    'eating less',
    'appetite',
    'won\u2019t eat',
    "won't eat",
    'refuse food',
  ]),
  'low energy' => _hasAny(text, const [
    'letharg',
    'tired',
    'sleepy',
    'sleeping a lot',
    'sleep',
    'low energy',
    'weak',
  ]),
  'coughing' => _hasAny(text, const ['cough', 'sneeze', 'hack']),
  'eye irritation' => _hasAny(text, const ['eye', 'squint']),
  'ear bother' => _hasAny(text, const ['ear', 'head shak']),
  'swelling' => _hasAny(text, const ['swell', 'lump', 'bump']),
  _ => false,
};

/// Matches the user's text against symptom keywords, then fills the pet's
/// name into the follow-up and escalation copy.
_Symptom? _matchSymptom(String text, String petName) {
  const defs = [
    (
      'bleeding',
      'where it\u2019s coming from and roughly how much',
      'If it\u2019s more than a few drops or won\u2019t stop, call the clinic now.',
    ),
    (
      'breathing changes',
      'whether {p}\u2019s gums look their normal colour',
      'If {p} is struggling to breathe, call the clinic right away.',
    ),
    (
      'vomiting',
      'how often it\u2019s happening and whether water stays down',
      'If {p} can\u2019t keep water down, let\u2019s see them today.',
    ),
    (
      'diarrhea',
      'how long it\u2019s been going on and whether {p} is still drinking',
      'If there\u2019s blood in it or {p} goes limp, call the clinic now.',
    ),
    (
      'limping',
      'which leg it is and whether {p} will put weight on it',
      'If {p} won\u2019t bear weight at all, we should see them soon.',
    ),
    (
      'scratching',
      'if there\u2019s any redness or hair loss',
      'If it spreads or {p} seems uncomfortable, let\u2019s have a look this week.',
    ),
    (
      'appetite change',
      'how long it\u2019s been going on and whether water intake is normal',
      'If {p} skips more than two meals, we should check them over.',
    ),
    (
      'low energy',
      'whether {p} is still eating and drinking normally',
      'If {p} is limp or unresponsive, call the clinic right away.',
    ),
    (
      'coughing',
      'whether there\u2019s any nasal discharge',
      'If the cough is harsh or {p} gags, let\u2019s have a listen soon.',
    ),
    (
      'eye irritation',
      'whether there\u2019s discharge or swelling',
      'Eyes can turn quickly — if it worsens today, bring {p} in.',
    ),
    (
      'ear bother',
      'any odour or discharge from the ear',
      'If {p} is shaking their head a lot, we should take a look.',
    ),
    (
      'swelling',
      'how quickly it appeared',
      'If it\u2019s growing fast or {p} is in pain, don\u2019t wait on it.',
    ),
  ];
  for (final (label, followUp, escalation) in defs) {
    if (_symptomHit(label, text)) {
      return _Symptom(
        label,
        followUp.replaceAll('{p}', petName),
        escalation.replaceAll('{p}', petName),
      );
    }
  }
  return null;
}

/// Maps a staff role to the chat author shown on its bubbles.
ChatAuthor authorForRole(StaffRole role) => switch (role) {
  StaffRole.vet => ChatAuthor.vet,
  StaffRole.vetAssistant => ChatAuthor.vetAssistant,
  StaffRole.groomer => ChatAuthor.groomer,
};
