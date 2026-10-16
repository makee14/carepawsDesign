import 'package:carepaws/data/models.dart';
import 'package:carepaws/services/staff_replies.dart';
import 'package:flutter_test/flutter_test.dart';

/// Refactor pin for the staff_replies symptom-table merge (ponytail pass):
/// the `_symptomHit` keyword switch and the `defs` record list hold the same
/// keywords in the same order, which is one table waiting to happen. Merging
/// them must not change a single reply — every symptom's label, follow-up
/// and escalation, plus first-match ordering, is pinned here. Green before
/// the merge and green after; a dropped keyword, a reordered row or a
/// mangled string fails loudly.
void main() {
  const pet = 'Biscuit';

  String reply(String text) => composeStaffReply(
    role: StaffRole.vet,
    userText: text,
    petName: pet,
    clinicOpen: true,
  );

  /// [trigger] must match exactly one symptom; [label], [followUp] and
  /// [escalation] are distinctive fragments of its table row.
  void pinsSymptom(
    String trigger,
    String label,
    String followUp,
    String escalation,
  ) {
    final r = reply(trigger);
    expect(r, contains(label), reason: trigger);
    expect(r, contains(followUp), reason: trigger);
    expect(r, contains(escalation), reason: trigger);
  }

  test('every symptom row answers with its own label, follow-up, escalation', () {
    pinsSymptom(
      'there is blood on his paw',
      'bleeding',
      'where it',
      'more than a few drops',
    );
    pinsSymptom(
      'panting a lot',
      'breathing changes',
      'gums look their normal colour',
      'struggling to breathe',
    );
    pinsSymptom(
      'vomiting twice today',
      'vomiting',
      'how often it',
      'keep water down',
    );
    pinsSymptom(
      'diarrhea since morning',
      'diarrhea',
      'still drinking',
      'blood in it',
    );
    pinsSymptom(
      'limping on his leg',
      'limping',
      'which leg it is',
      'bear weight at all',
    );
    pinsSymptom(
      'scratching nonstop',
      'scratching',
      'redness or hair loss',
      'If it spreads',
    );
    pinsSymptom(
      'not eating today',
      'appetite change',
      'water intake is normal',
      'two meals',
    );
    pinsSymptom(
      'lethargic all day',
      'low energy',
      'eating and drinking normally',
      'limp or unresponsive',
    );
    pinsSymptom(
      'coughing at night',
      'coughing',
      'nasal discharge',
      'have a listen soon',
    );
    pinsSymptom(
      'eye is red',
      'eye irritation',
      'discharge or swelling',
      'Eyes can turn quickly',
    );
    pinsSymptom(
      'ear smells bad',
      'ear bother',
      'odour or discharge',
      'shaking their head a lot',
    );
    pinsSymptom(
      'lump on his side',
      'swelling',
      'how quickly it appeared',
      'growing fast',
    );
  });

  test('first matching row wins when keywords overlap', () {
    // 'bleed' (row 0) beats 'paw' (limping's row).
    expect(reply('his paw is bleeding'), contains('bleeding'));
    // 'leg' reaches limping only — no earlier row claims it.
    expect(reply('hurt his leg'), contains('limping'));
  });
}
